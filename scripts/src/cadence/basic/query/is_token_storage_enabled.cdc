import FungibleToken from 0xFungibleToken
import <Token> from <TokenAddress>

access(all) fun main(address: Address) : Bool {
  let account = getAccount(address)
  
  let receiver = account.capabilities.exists(<TokenReceiverPath>)
  let balance = account.capabilities.exists(<TokenBalancePath>)

  return receiver && balance
}