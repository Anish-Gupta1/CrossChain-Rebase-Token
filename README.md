# Cross-chain Rebase Token

1. A Protocol that allows user to deposit in vault, and recieve rebase tokens that represent their underlying balance.
2. Rebase Token -> balanceOf funciton is dynamic to show changing balance with time
   - Balance increases linearly with time.
   - mint tokens to our user everytime theey perform an action.
3. Interest Rate
   - Individually set interest rate for each user based on some Global interest rate.
   - Global interest can only be decreasing to incentivise/reward early users.
