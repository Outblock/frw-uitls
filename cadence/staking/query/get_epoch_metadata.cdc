import FlowEpoch from 0xFlowEpoch

access(all) fun main(epochCounter: UInt64): FlowEpoch.EpochMetadata {
  return FlowEpoch.getEpochMetadata(epochCounter)!
}