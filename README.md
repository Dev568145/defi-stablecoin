1. (Relative Stability) Anchored or Pegged -> $1.00
   1. Chainlink Price Feed
   2. Set a function to exchange ETH & BTC -> $$$
2. Stability Mechanism (Minting): Algorithmic (Decentralized)
   1. People can only mint the stablecoin with enough collateral (coded)
3. Collateral: Exogenous (Crypto)
   1. wETH
   2. wBTC

- calculate health factor function
- set health factor is debt is zero
- added multiple view functions

What are our invariant/properties?

1. Some proper oracle use ✅
2. Write more tests
3. Smart Contract Audit Preperation

How to protect protocol if oracle pricefeed goes down?

1. Alternative oracle (pyth) that the protocol automatically switches to if chainlink oracle goes down
2. Build in circuit breakers that temporarily pauses the protocol if both oracles are down
