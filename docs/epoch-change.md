### Owned-object-only transaction:

A block B is said to certify a transaction tx if the causal history of B
contains 2f+1 votes for tx. However, the block carries an overriding bit,
called **epoch-change-bit**, which when set to 1 (default set to 0), indicates that
the block does not certify any transaction, regardless of the causal history.
A validator can execute the transaction (asynchronously) as soon
as it sees 2f+1 votes for it.

A transaction is considered final if in any view of the DAG, 2f+1 authorities
have published blocks which certify the transaction.

### Epoch Change
1. Epoch Change begins at a pre-determined commit, for example, when enough
ready messages from the new committee are sequenced.
2. Validator stops acquiring locks and casting votes. The epoch-change-bit in
validator's blocks is now set to 1 for all future rounds. Similar to steady
state, the validator's block references sufficient blocks (n-f) from previous
round including its own.
3. Once blocks from 2f+1 authorities, containing the epoch-change-bit, are
sequenced, epoch is considered closed.
4. Any continuing validators reset their object locks, and revert execution of
transactions for which no certifying block has been committed.

### Safety:
Finalised transactions are never reverted.
- All owned-object-only transactions have at least one certificate sequenced
before the epoch close.

**Proof.**
It is sufficient to prove that all owned-object-only transactions
that are considered final (i.e. having certifying blocks from 2f+1 authorities)
have one certifying block sequenced in the current epoch.
(Additionally, note that no conflicting transaction can have a certifying block
by quorum intersection.)
For contradiction sake, assume that the epoch closed before any certifying
block for a finalised transaction tx could be sequenced. For the epoch to
close, 2f+1 nodes published a block with the epoch-change-bit set to 1. For the
transaction to be finalized, 2f+1 nodes published a block which certifies the
transaction.
By quorum intersection, one correct node published a block B1 certifying
transaction tx and block B2 with epoch-change-bit set to 1 such that B1 is not
present in the causal history of B2. Because a certifying block cannot have the
epoch-change-bit set to 1, B1 is necessarily published in an earlier round than
that of B2. B1 is therefore contained in the causal history of B2, which is a
contradiction.

### Liveness:
Epoch change process terminates for all correct validators eventually.

**Proof.**
Inherited from liveness of underlying BA (Byzantine Agreement).

### When does a validator shut down sync?
A correct validator should not shut down sync as soon as it considers the epoch
closed. We instead wait for f+1 validators to have considered the epoch closed,
and then stop the sync.