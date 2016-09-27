_     = require 'lodash'
path  = require 'path'

module.exports = (config) ->
  networkValue = "ens192 -i eth0 @CONTAINER_NAME@ dhclient @#{config.vlan}"
  networkEnv = 'eth0_pipework_cmd'

  appdef2compose: (instance, doc) ->
    delete doc.name
    delete doc.version
    delete doc.pic
    delete doc.description
    doc

  augmentCompose: (instance, options, doc) ->
    addNetworkContainer = (serviceName, service) ->
      labels = _.extend {}, service.labels
      labels['bigboat/service/name'] = "net-#{serviceName}"
      labels['bigboat/container/type'] = 'net'
      subDomain = "#{instance}.#{config.domain}.#{config.tld}"
      netcontainer =
        image: 'www.docker-registry.isd.ictu:5000/pipes:1'
        environment: eth0_pipework_cmd: networkValue
        hostname: "#{serviceName}.#{subDomain}"
        dns_search: subDomain
        net: 'none'
        labels: labels

      doc["net-#{serviceName}"] = netcontainer

    addNetworking = (serviceName, service) ->
      delete service.hostname
      service.net = "container:net-#{serviceName}"
      # if service.depends_on
      #   service.depends_on.push "net-#{serviceName}"
      # else
      #   service.depends_on = ["net-#{serviceName}"]
      # if service.environment?.push
      #   service.environment.push "#{networkEnv}=#{networkValue}"
      # else
      #   service.environment = _.merge {}, {"#{networkEnv}": networkValue}, service.environment

    addVolumeMapping = (serviceName, service) ->
      bucketPath = path.join config.dataDir, config.domain, options.storageBucket if options.storageBucket
      service.volumes = service.volumes?.map (v) ->
        vsplit = v.split ':'
        if vsplit.length is 2
          if vsplit[1] in ['rw', 'ro']
            v
          else if bucketPath
            "#{path.join bucketPath, vsplit[0]}:#{vsplit[1]}"
          else vsplit[1]
        else if vsplit.length is 3
          if bucketPath
            "#{path.join bucketPath, vsplit[0]}:#{vsplit[1]}:#{vsplit[2]}"
          else "#{vsplit[1]}:#{vsplit[2]}"
        else v

    for serviceName, service of doc
      addNetworkContainer serviceName, service
      addNetworking serviceName, service
      addVolumeMapping serviceName, service

    doc
