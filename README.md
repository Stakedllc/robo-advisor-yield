# The Robo-Advisor for Yield

Staked introduces the Robo-Advisor for Yield (RAY), the easiest way to earn the highest yield on ETH, DAI, and USDC holdings. Users deposit funds into the RAY smart contract, customize which protocols should be considered, and an off-chain oracle monitors rates on eligible protocols. RAY automatically moves funds to the highest-yielding at option at any time. Users receive an ERC-721 token representing the value of positions they own.

RAY will support an expanding number of yield-generating opportunities, with initial support for Compound, dYdX, and bZx. Decisions about which protocols will be supported and key system variables will be handled through governance. This allows capital providers and smart contract authors to collaborate profitably in a decentralized manner.

RAY is a work in progress and several anticipated features have yet to be implemented. Please see the [Roadmap](https://github.com/Stakedllc/robo-advisor-yield/wiki#roadmap) and [contact us](https://t.me/staked_official) if you have suggestions for greater clarity or better functionality.

## Table of Contents

- [Overview](https://github.com/Stakedllc/robo-advisor-yield/wiki)
- [Developers (deployed addresses, documentation)](https://staked.gitbook.io/staked/ray/smart-contract-integration)
- [Security](https://github.com/Stakedllc/robo-advisor-yield/wiki/Security)
- [Requests for Contracts](https://github.com/Stakedllc/robo-advisor-yield/wiki/Requests-for-Contracts)
- [Frequently Asked Questions](https://staked.zendesk.com/hc/en-us/sections/360006555872-Robo-Advisor-for-Yield-FAQs)
- [License](https://github.com/Stakedllc/robo-advisor-yield/blob/master/LICENSE)

## Installation
To integrate with the Robo-Advisor for Yield, pull the repository from GitHub and install its dependencies. You will need [yarn](https://yarnpkg.com/en/) or [npm](https://docs.npmjs.com/cli/install) installed.

``` 
git clone https://github.com/Stakedllc/robo-advisor-yield.git
cd robo-advisor-yield
yarn or npm install 
```

## Testing
This project uses the [Truffle Framework](https://www.trufflesuite.com/). Contract tests are defined under the [test directory](). Truffle leverages the [Mocha Test Framework](https://mochajs.org/). 

The below commands run tests using Truffle/Mocha. The tests use a chain seeded with the RAY protocol. An example test for RAY smart contract integration exists [here]().

### Using [Docker](https://www.docker.com/)
------------------------------------------------------

Requires a running [Docker](https://www.docker.com/) engine

```
bash ./scripts/container_tests.sh
```
or
```
docker build . -t robo_advisor_yield
docker-compose up chain
docker-compose up test
```

### Without Docker
------------------------------------------------------

```
yarn run chain
yarn run test
```

## Discussion
For any questions about the product, please visit us in our [Community Telegram chat](https://t.me/staked_official) to discuss.

_Copyright © 2019 Staked Securely, Inc._
