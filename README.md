## Usage

### Install dependencies
```shell
yarn install
```

### Build

```shell
yarn build
```

or via forge directly:
```shell
forge build
```

### Test

via yarn:

```shell
yarn test
```

or via forge directly:
```shell
forge test
```

### Coverage

via yarn:
```shell
yarn coverage
```

or via forge directly:
```shell
forge coverage
```

### Deploy

Create .env file on base of .env.example and specify needed variables.
Run deploy:

via yarn:
```shell
yarn deploy
```

or via forge directly:
```shell
source .env && forge script script/StakeManager.s.sol:DeployProxy --rpc-url $RPC_URL --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast -vvvv --ffi
```
