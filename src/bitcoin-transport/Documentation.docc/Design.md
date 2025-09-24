# Node Service Design

The ``NodeService`` actor encapsulates all the peer-to-peer transport protocol logic.

## Peer management

A node will keep a list of all connected peers. A peer can be incoming or outgoing. For each peer a series of state properties is kept.

## Message processing

Whenever a message is received from one of the peers the appropriate actions need to be taken. At the end of the processing a number of response messages is likely enqueued to send back to the originating peer.

## Blockchain events

The node listens to blockchain events like the recognition of a new chain tip after fully validating and connecting a block.

An event might result in new messages being generated and sent to our peers. This is the case of relaying a block or a transaction after it is validated by the blockchain/mempool service.
