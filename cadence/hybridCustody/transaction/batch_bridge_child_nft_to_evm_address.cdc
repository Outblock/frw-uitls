import MetadataViews from 0xMetadataViews
import ViewResolver from 0xMetadataViews
import NonFungibleToken from 0xNonFungibleToken

import FungibleToken from 0xFungibleToken
import FlowToken from 0xFlowToken
import FungibleTokenMetadataViews from 0xFungibleToken

import ScopedFTProviders from 0xFlowEVMBridge

import EVM from 0xEVM

import FlowEVMBridgeUtils from 0xFlowEVMBridge
import FlowEVMBridge from 0xFlowEVMBridge
import FlowEVMBridgeConfig from 0xFlowEVMBridge

import HybridCustody from 0xHybridCustody
import CapabilityFilter from 0xCapabilityFilter



transaction(nftIdentifier: String, child: Address, ids: [UInt64], recipient:String) {
  prepare(signer: auth(CopyValue, BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {
    /* --- Reference the signer's CadenceOwnedAccount --- */
    //
    // Borrow a reference to the signer's COA
    // let coa = signer.storage.borrow<auth(EVM.Bridge) &EVM.CadenceOwnedAccount>(from: /storage/evm)
    //     ?? panic("Could not borrow COA from provided gateway address")
    
    let m = signer.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
      ?? panic("manager does not exist")
    let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")
    
    // Construct the NFT type from the provided identifier
    let nftType = CompositeType(nftIdentifier)
      ?? panic("Could not construct NFT type from identifier: ".concat(nftIdentifier))
    let nftContractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: nftType)
      ?? panic("Could not get contract address from identifier: ".concat(nftIdentifier))
    let nftContractName = FlowEVMBridgeUtils.getContractName(fromType: nftType)
      ?? panic("Could not get contract name from identifier: ".concat(nftIdentifier))

    
    /* --- Retrieve the NFT --- */
    //
    // Borrow a reference to the NFT collection, configuring if necessary
    let viewResolver = getAccount(nftContractAddress).contracts.borrow<&{ViewResolver}>(name: nftContractName)
      ?? panic("Could not borrow ViewResolver from NFT contract")
    let collectionData = viewResolver.resolveContractView(
        resourceType: nil,
        viewType: Type<MetadataViews.NFTCollectionData>()
      ) as! MetadataViews.NFTCollectionData? ?? panic("Could not resolve NFTCollectionData view")
    let collection = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(
        from: collectionData.storagePath
      ) ?? panic("Could not access signer's NFT Collection")


    let capType = Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>()
    let controllerID = childAcct.getControllerIDForType(type: capType, forPath: collectionData.storagePath)
      ?? panic("no controller found for capType")
    
    let cap = childAcct.getCapability(controllerID: controllerID, type: capType) ?? panic("no cap found")
    let providerCap = cap as! Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>
    assert(providerCap.check(), message: "invalid provider capability")
    
    let id = ids[0]
    // Get a reference to the child's stored vault
    let collectionRef = providerCap.borrow()!
    let childNft <- collectionRef.withdraw(withdrawID: id)
    collection.deposit(token: <-childNft)
    // // Withdraw tokens from the signer's stored vault
    let currentStorageUsage = signer.storage.used
    let nft <- collection.withdraw(withdrawID: id)
    let withdrawnStorageUsage = signer.storage.used
    let approxFee = FlowEVMBridgeUtils.calculateBridgeFee(
        bytes: 400_000
      ) + (FlowEVMBridgeConfig.baseFee * UFix64(ids.length))
    /* --- Configure a ScopedFTProvider --- */
    //
    // Issue and store bridge-dedicated Provider Capability in storage if necessary
    if signer.storage.type(at: FlowEVMBridgeConfig.providerCapabilityStoragePath) == nil {
      let providerCap = signer.capabilities.storage.issue<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(
        /storage/flowTokenVault
      )
      signer.storage.save(providerCap, to: FlowEVMBridgeConfig.providerCapabilityStoragePath)
    }
    // Copy the stored Provider capability and create a ScopedFTProvider
    let providerCapCopy = signer.storage.copy<Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>>(from: FlowEVMBridgeConfig.providerCapabilityStoragePath)
      ?? panic("Invalid Provider Capability found in storage.")
    let providerFilter = ScopedFTProviders.AllowanceFilter(approxFee)
    let scopedProvider <- ScopedFTProviders.createScopedFTProvider(
        provider: providerCapCopy,
        filters: [ providerFilter ],
        expiration: getCurrentBlock().timestamp + 1.0
      )
        
    let recipientEVMAddress = EVM.addressFromString(recipient)

    FlowEVMBridge.bridgeNFTToEVM(
      token: <- nft,
      to: recipientEVMAddress,
      feeProvider: &scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    )
    var idx = 0
    for nftId in ids {
      if idx == 0 {
        idx = idx + 1
        continue
      }

      FlowEVMBridge.bridgeNFTToEVM(
        token: <- collectionRef.withdraw(withdrawID: nftId),
        to: recipientEVMAddress,
        feeProvider: &scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
      )
      idx = idx + 1
    }
    // Destroy the ScopedFTProvider
    destroy scopedProvider
  }

}
