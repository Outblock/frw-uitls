import * as fcl from '@onflow/fcl'
import { readCadenceScripts, replaceAddress } from './cadence'

let scriptsMap = null

export const exportScripts = async (addressMapping = {}) => {
  scriptsMap = await readCadenceScripts('./', addressMapping)
  return scriptsMap
}

export const executeQuery = async (scriptPath, args, addressMapping = {}) => {
  try {
    let pathArr = scriptPath.split('/')
    if (scriptsMap == null) {
      scriptsMap = await readCadenceScripts('./')
    }

    let script = scriptsMap[pathArr[0]][pathArr[1]]
    if (script == null) {
      throw new Error(`Script ${path} not found`)
    }
    script = replaceAddress(script, addressMapping)
    const response = await fcl.send([fcl.script(script), fcl.args(args)])
    return await fcl.decode(response)
  } catch (error) {
    console.log(error)
  }

}

export const exportScript = async (scriptPath, addressMapping = {}) => {
  let pathArr = scriptPath.split('/')
  if (scriptsMap == null) {
    scriptsMap = await readCadenceScripts('./')
  }
  let script = scriptsMap[pathArr[0]][pathArr[1]]
  script = replaceAddress(script, addressMapping)
  return script
}

export const executeTransaction = async (
  path,
  args,
  opts = {},
  addressMapping = {},
) => {
  let pathArr = path.split('/')
  if (scriptsMap == null) {
    scriptsMap = await readCadenceScripts('./')
  }

  let script = scriptsMap[pathArr[0]][pathArr[1]]
  if (script == null) {
    throw new Error(`Script ${path} not found`)
  }
  script = replaceAddress(script, addressMapping)

  const response = await fcl.send([
    fcl.transaction(script),
    fcl.args(args),
    fcl.proposer(opts.proposer || opts.authz),
    fcl.payer(opts.payer || opts.authz),
    fcl.authorizations(opts.auths || [opts.authz]),
    fcl.limit(opts.limit || 9999),
  ])

  return await fcl.decode(response)
}


