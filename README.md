## Usage

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Coverage

```shell
forge coverage
```

### Deploy

Create .env file on base of .env.example and specify needed variables.
Run deploy:

```shell
source .env && forge script script/StakeManager.s.sol:DeployProxy --rpc-url $RPC_URL --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast -vvvv --ffi
```
