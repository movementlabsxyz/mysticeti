Mysticeti: design decisions & latest architecture

Objective: Have a single simple DAG based broadcast structure, allowing validators to:

- (1) share transactions once, and disseminate them to all, 
- (2) share votes on transactions 
as part of a consistent broadcast based protocol, once per node 
- (3) share potential 
conflicting transactions and 
- (4) allow agreement on consecutive commit sets of transactions.

Thus the design combines and integrates the Sui fast path & the narwhal-based consensus path
in Sui.

The scaling logic is as follows: Mysticeti is used for transport of transactions and votes,
however the logic by which a validator votes or rejects a transaction is external to the
mysticeti component. As a result, we can shard transactions by txid and use multiple mysticeti
instances to broadcast the transactions and votes relating to them. All of the instances 
vote according to a common set of object locks, for owned objects. For shared objects 
commits between instances been to be used in lock step to create a common sequence.

Issues we are trying to mitigate:

- Mass of redundant transaction sends: currently each validator receives the transaction 
3 times. One to sign it, one as a certificate, and then again as part of consensus. We want to
only share transaction bodies once.

- Mass of signatures and verifications: currently for each transaction clients / full nodes
need to create certiicates, involving each validator signing each signature, and checking a 
certificate which is either BLS (expensive) or linear in the number of validators. We want to 
drmatically reduce the cost of signature creation and certification, and decouple it from the 
number of transactions (couple it with latency instead).

- Separate consistent broadcast and consensus leads to the need to maintain separate protocols
separate network, with different retry / sync / connection management sub systems. Integrating 
these too deeply is hard to maintain as complexity increases; keeing modules separate means that
they are poorly coordinated and compete with each other for resources.

- The choice of which validator places a certificate into consensus has become complex, due 
to the longer delay between expecting a transaction and seeing it, as well as the fact that all
validators are given the certificate in Sui. A model by which one validator is responsible for
putting a transaction into the system, with a very short delay to observe correct inclusion is 
simpler and better.

## The DAG creation and invariants:

A mysticeti block contains:
- A creator authority, a round number and a digest (acts as a reference for the block)
- Base statements: transaction payloads, or transaction votes.
- Included references: references that the block depends on, which need to be processed 
  before this block is processed.
- A signature from the creator over all the data.

Some key invariants hold to ensure the validtiy of a block: all included references are 
of a lower round; at least >2/3 stake from round r - 1 are included in a block at round r
(lower round references may also be included).
The authority is known and the signature valid over all data in the block. A correct 
block should contain votes only on transactions included previously in this block, or 
any included blocks (transitivelly). 

## DAG processing: Certification

As a node receives blocks it processesed them in causal order ensuring included references
are processed before each block referring to them. A the base statements of each block are 
processed by accumulating votes, positive and negative, for each seen transaction. When >2/3
positive votes are seen the transaction is considered certififed; A correct node can also 
reject a transaction with an optional conflicting transaction. Correct nodes never change 
their votes (between accept and conflict).

As blocks are processed by a validator they are included in the next block of the validator as
references. Any transactions or votes presented by the validator are also included in the 
next block as base statements. A process of reference compression allows a validator to only
include the causally latest reference allowing others to infer previous ones. 

End of epoch: once a node decides to reach the end of epoch, it needs to vote on all 
transactions that were sequenced in its own history. By default it rejects all transactions
that it may not accept. Then for all certified transactions it continues to run the 
protocol until they are sequenced, or until >2/3 close epoch transactions are seen. When all
transactions certified locally are sequenced it sends its end-of-epoch transaction.

## DAG processing: Consensus

We determine a period, ie every period many rounds we elect a leader ( so if period is 3, we elect
at rounds 0, 3, 6, ...). We consider that a block "votes" for another block if the other 
block is included in its history. Only the first block from an (authority, round) included
direcly or indirecly is "voted" for. When a block votes for a past block we consider the 
creator authority or the authority that included it in a block votes for it.

We call every round period * k - 1 (for k = 1, 2, 3, ...) a decision round. We look at how many 
votes blocks at round period * (k -1) have. If a block has received votes from >2/3 validators 
by stake in the history of a block we consider it certified. If the leader block for k is certified 
by >2/3 blocks in the decision round for k we commit it.

When a leader at round k is committed, we consider all leaders between the last committed leader 
and the leader at k. If the leader k' < k is certified by at least one block in its decision round 
within the causal history of k, we commit it first, and then consider the next one.

## From commits to executions:

As soon as a transaction is certified, and only contains owned objects, it may be executed by the 
validator. The validator then includes in its block sufficient evidence to ensure all will eventually 
execute. This is also sufficient evidence to ensure that eventually it will be sequenced.

If a certified transaction contains shared objects, the certificate needs to be included in a commit 
at the time of the commit it is assigned a version number of each shared object, and then it may be 
executed. 

A validator may not vote to close the epoch unless all transactions that it has observed as certified 
are executed and sequenced in a causal order. However, a validator may vote to reject transactions after 
some time, to allow for the epoch to close. 


## Sync & Net protocol: 

All communications
are done as a request / response (there is no push as in Sui/NW) and we try to unify the 
sync and common paths as much as possible. In the common case all nodes send a request to all
other nodes for their blocks after a certain round number, and may request any block
on a need by need basis that is included in a block from the party that created it or included it.

We follow a 2-level sync protocol. Each commit of the consensus makes a commit
set of blocks, and we can request to sync up to a commit set by round number. Commit 
sets are shared between validators so one can request them from others. For the very latest 
blocks we maintain succinct structure of blocks not in a commit set, and exchange it to 
allow another node to send the missing blocks, or request more blocks. 

TODO Things we need to co-design:
- sync recovery
- persistence points
- safe close
- high perf interface to other parts
- network design
- crash recovery
- batch async client api to interact with system

## Key APIs:

### Core-Mysticeti API

This is the interface that the validator code uses to "talk to" the mysticeti logic that runs 
on the validator.

- `BroadcastTransaction(transactions: Vec<Transactions>)` : put a number of transactions into the 
  broadcast channel, so that other validators can vote on them. A validator should only place a
  transaction in the channel if it is ready to vote for it positivelly.
- `BroadcastVotes(votes: Vec<(TransactionId, Votes)>)` : place a number of positive or negative 
  votes from itself associated with specific transactions into the broadcast channel. Other 
  validators will receive the votes and tally them to make certificates.
- `ProcessBlocks( blocks: Vec<MysticetiBlocks>)` : the core asks mysticeti to process a number 
  of blocks from other validators.
- `Shutdown` : asks the mysticeti logic to close the channel, after it has sent or sequenced all
  data it has committed to send or sequence.

### Read APIs 

allow the core to determine:
- Blocks missing.
- Transactions received requiring votes
- Transactions that have been certified.
- Blocks committed and commit sets of transactions.

### Validator-Validator API

This is the networked interface that mysticeti logic on a validator uses to "talk to" the 
mysticeti logic on a different validator. It all takes the form of RPC request / response, but
some responses are streamed and use a long poll. 

- **Subscribe at round number**: request a validator at a round number, and the Validator
  will send its own blocks after that round number, for a specified number of blocks.
- **Subscribe by hash**: request a blocks from a validator using a set of hashes. These blocks 
  may be created by others but the validator has included them.
- **Get commit blocks by round number**: request all blocks between two committed rounds, by 
  round numbers for start and end.

Note that there are **no push APIs**. All APIs are unreliable, in that they may fail 
without internal re-transmission. The reliability of the protocol is not based on a
per message reliable transmission, but rather on a repetition of the overall protocol
loop.