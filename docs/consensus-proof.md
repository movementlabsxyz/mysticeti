## The proof of safety and liveness for Mysticeti Consensus

Brief description of scheme:
- Validators have stake that is stable throughout the epoch.
- Quorums are formed when validators with >2/3 stake support a decision.
- The protocol proceeds in rounds 0, 1, 2, 
- Each round correct validators create a single block for that round, 
  referenced as (validator, round, digest).
- A block contains an ordered list of references to previous blocks, 
  and none to current or future round blocks. We call these blocks "included".
- A block contains at least a quorum of references to blocks
  from the previous round.
- A correct block starts with a reference to the previous block from the
  creator validator.
- The system is initialized with blocks for round 0 from all 
  validators.
- A block also contains contents, which are playloads to be sequenced, 
  but otherwise play no role in the agreement protocol.

### Definition of block support

A block A is supported by another (causally future) block B if A is the first 
block from the (validator, round) of A that is in the causal history of B. The
concept of "first" is defined in relation to the order of included blocks in 
the history of B, and defined recursivelly as follows:

B supports all blocks supported in its included blocks in order. For each included
block X, B supports in order the blocks supported by the included block (X), and the
block X itself. If an included  block supports a past block that conflicts with an
earlier supported block, the earlier remains supported and the later ignored. This
implements a depth first, right-to-left in includes, support collection.

As a result two lemmas hold:

Lemma 1. A block only supports a single block from a given (authority, round).

Lemma 2. A correct node will only ever support in any of its blocks at most a single
 (authority, round) block.

Lemma 3. Only a single block at a (val, round) will ever gather a quorum of support.

**Proofs:**

Lemma 1: 
By the definition of support for a block only a single (val, round) block can be
supported from a future block.  

Lemma 2: 
since a correct validator includes its last block first in any subsequent
block, the subsequent block initially supports all previously supported blocks, and 
any additional blocks included supporting conflicting blocks, will not overwrite 
this "earlier" support. Thus a validator will never change which (val, round) block
is supported once one is supported.


Lemma 3:
By quorum intersection, if two blocks A and A' with the same (val, round)
gather support, they intersect at at least one correct node. This means that the 
correct node in one block supports A and in another block support A', which by 
Lemma 2 means A = A'.

### Block Certified Support

A block B certifies a casually included block A if the subgraph connecting A to B
contains 2f+1 blocks from distinct authorities that support A. Note that in this
calculation equivocating blocks may support different blocks, and yet they are 
counted towards supporting each of the different blocks (not only the first is
counted as when we define block support.)

The following lemmas hold:

Lemma 4: 
only a single block from an authority & round will be certified across
any future blocks.

Lemma 5: 
if a block B certifies a block A, any block C that includes B will
also certify A.

**Proofs:**

Lemma 4: A block can certify at most one (authority, round) block (Lemma 1).
Therefore, consider two blocks that certify different blocks for the same
authority round. They each contain in their history 2f+1 support for the 
respective equivocating blocks they support. However this stake must intersect
on a correct node. A correct by lemma 2 will not support two different blocks
and therefore there is a contradiction that proves the lemma.

Lemma 5: The block C contains the full history of block B, which contains 
2f+1 support for block A, and therefore block C also certifies block A.

### Period, Leader rounds & Decision rounds

The period (p > 1) is the number of rounds between leaders. Rounds with leaders are 
p * k (for k = 1, 2, 3, ...)  ie non-zero rounds divisible by the period. During these 
rounds a validator is deterministically chosen by all nodes to act as a leader. The 
round preceding the leader round (ie p*(k+1) -1, for k = 1, 2, 3, 4) are called 
decision rounds, since we decide based on blocks on these rounds whether to commit 
a leader (retrospectively for round p*k) or not. We call these the leader for k and
the decision round for k.

After a node passes a decision round for k (it has a quorum of blocks for
round p*(k+1) - 1, (recall that a quorum of blocks is needed before passing to the next round)),
it checks whether there is a quorum of certified support for a block (call "X") from
the leader at the leader round k (ie round k*p). If so the block ("X") is committed.

When a leader at k is committed, the node goes back and checks for each leader Lk round
after the last commit: If the leader Lk is in the causal graph of the committed leader, and 
and the decision round for Lk contains at least one block certifying the leader Lk
we first commit leader Lk. This continues until the last leader (that does have support) 
is committed.

Lemma 6a: 
If at round x, 2f+1 blocks from distinct authorities certify a block A at a previous round
then **any block in the next round will contain at least 1 block that certifies A at round x.**

Lemma 6b:
If at a round x, 2f+1 blocks from distinct authorities certify a block A at a previous
round, then **all blocks at future rounds > x will certify that block**.

Lemma 7: 
If some correct node commits a leader at round k, then all correct nodes will commit the
leader at round k before committing any later leaders.

Theorem 8 (safety):
All correct nodes commit a consistent sequence of leaders (ie the commit of one is 
a prefix/substring of the commit of another.)

Theorem 9 (liveness):
All correct nodes eventually commit all leaders up to the end of the epoch.

Lemma 10:
The full causal history of the final block to be committed will be included in the
commit.

**Proofs:**

Lemma 6a: 
A block at round x+1 needs to link to 2f+1 blocks at round x. By quorum intersection
one of the 2f+1 blocks included must intersect with 1 honest block from the 2f+1 blocks
that certify A. 

Lemma 6b: A block at round x+1 at least one block that certifies A, by lemma 6a. 
By lemma 5 since this included block certifies A all blocks at round x+1 will 
also certify A. The argument applies recursivelly for round x+1, which also has 2f+1
certified blocks for A, and so on for ever.

Lemma 7: For the sake of contradiction, assume that if some correct node commits a leader
at round k, then there exists another correct node X that commits leader at round >k
without first committing the leader at round k.
Consider the immediately next leader k' (>k) committed by X. In X's view, either (i) the
committed leader k' does not contain the leader at round k in its causal graph, or (ii) none
of the blocks in the decision round for k certify the leader Lk.
(i) is a contradiction due to Lemma 6 and the fact that a block can not certify another block
without containing it in its causal graph. (ii) is also a contradiction because by definition
f+1 correct nodes certify Lk in its corresponding decision round.

Theorem 8 (safety): consider two correct nodes with sequences that are not consistent. 
Then consider the first leader on which they diverge in their commits. By lemma 7 if 
one of them has committed the leader all other ones, will first commit this leader, 
which means the committed leader where they diverge is the same. Leading to a 
contradiction, proving the theorem.

Theorem 9 (liveness): USE TIMEOUTS!