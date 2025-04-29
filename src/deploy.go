package main

import (
	"fmt"

	"github.com/foundry-rs/foundry/common"
	"github.com/foundry-rs/foundry/forge"
)

func main() {
	// Create a provider (local or remote)
	provider, err := common.NewRPCProvider("http://127.0.0.1:8545") // Local blockchain from `anvil`
	if err != nil {
		panic(err)
	}

	// Load the contract
	contract, err := forge.NewContract("Governance.sol")
	if err != nil {
		panic(err)
	}

	// Deploy contract here with a constructor
	deployedAddress, err := contract.Deploy(provider, 0, "0xYourTokenAddressHere", []common.Address{"0xApproverAddress1", "0xApproverAddress2"})
	if err != nil {
		panic(err)
	}

	fmt.Println("Deployed contract at address:", deployedAddress.Hex())
}
