-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install Cyfrin/foundry-devops && forge install foundry-rs/forge-std && forge install OpenZeppelin/openzeppelin-contracts

# Update Dependencies
update:; forge update

build:; forge build

FORK_NETWORK_ARGS := --fork-url base_mainnet --fork-block-number $(BLOCK_NUMBER) --etherscan-api-key etherscan_api_key

test :; forge test $(FORK_NETWORK_ARGS)

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast


ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

createSubscription:
	@forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)

addConsumer:
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS)

deployFactory:
	forge script script/DeploySwapSwapFactory.s.sol:DeploySwapSwapFactory --rpc-url base_mainnet --etherscan-api-key etherscan_api_key --verify --account dev --broadcast

gasCoverage:
	forge test $(FORK_NETWORK_ARGS) --gas-report

testExecuteSwapFromUSDCtoToken:
	forge test --mt testExecuteSwapFromUSDCtoToken $(FORK_NETWORK_ARGS) -vvvv

testExecuteSwapFromTokentoUSDC:
	forge test --mt testExecuteSwapFromTokentoUSDC $(FORK_NETWORK_ARGS) -vvv

testExecuteSwapFromETHtoToken:
	forge test --mt testExecuteSwapFromETHtoToken $(FORK_NETWORK_ARGS) -vvv

testSameDeployment:
	forge test --mt testSameDeployment $(FORK_NETWORK_ARGS) -vvvv