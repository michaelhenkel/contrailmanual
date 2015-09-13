#!/usr/bin/python
import yaml
import argparse
import json
from pprint import pprint

class Container:
  def __init__(self, containerName):
    self.containerName = containerName

  def create(self, containerConfig):
    self.name = self.containerName
    self.image = containerConfig['image']
    self.ip = containerConfig['ip']
    self.mask = containerConfig['mask']
    self.gateway = containerConfig['gateway']
    self.dns = containerConfig['dns']
    self.domain = containerConfig['domain']
    self.bridge = containerConfig['bridge']
    self.host = containerConfig['host']
    self.state = containerConfig['state']
    self.volumes = containerConfig['volumes']
    return self

  def show(self):
    print "Container %s" % self.name
    print "  Image:   %s" % self.image
    print "  IP:      %s" % self.ip
    print "  Mask:    %s" % self.mask
    print "  Gateway: %s" % self.gateway
    print "  Dns:     %s" % self.dns
    print "  Domain:  %s" % self.domain
    print "  Bridge:  %s" % self.bridge
    print "  Host:    %s" % self.host
    print "  Volumes: %s" % self.volumes
    print "  State:   %s" % self.state

  def get(self, property):
    if property == 'image':
      return self.image
    if property == 'ip':
      return self.ip
    if property == 'mask':
      return self.mask
    if property == 'gateway':
      return self.gateway
    if property == 'dns':
      return self.dns
    if property == 'domain':
      return self.domain
    if property == 'bridge':
      return self.bridge
    if property == 'host':
      return self.host
    if property == 'volumes':
      return self.volumes
    if property == 'state':
      return self.state

class SendHTTPData:
   def __init__(self, data, method, host, port, action):
       self.connection = 'http://' + host + ':' + port + '/' + action
       self.data = data

   def send(self):
       req = urllib2.Request(self.connection)
       req.add_header('Content-Type', 'application/json')
       response = urllib2.urlopen(req, self.data)
       return json.loads(response.read())
 
parser = argparse.ArgumentParser(description='docker manager')
parser.add_argument('-f','--file',
                   help='environment file')
parser.add_argument('-c','--containerName',
                   help='container name')
parser.add_argument('-p','--property',
                   help='container property')
parser.add_argument('-hi','--hostip',default='127.0.0.1',
                   help='container host')
parser.add_argument('-hp','--hostport',default=3288,
                   help='container host')
parser.add_argument("action",
                   help='show/list/get/create/destroy/start/stop')
args = parser.parse_args()

def toJson(containerObject):
  return json.dumps(dict((key, getattr(containerObject,key))
    for key in dir(containerObject)
      if key not in dir(containerObject.__class__)))

if __name__ == "__main__":
  if not args.file:
    envFile = 'environment.yaml'
  f = open(envFile,'r')
  yaml_file = f.read().strip()
  yaml_object=yaml.load(yaml_file)
  containerList = yaml_object['containers']
  containerArray = []

  for container in containerList:
    if container != 'containerdefault':
      newContainer = Container(container)
      containerObject = newContainer.create(containerList[container])
      containerArray.append(containerObject)

  if args.action == 'show':
    for container in containerArray:
      if container.name == args.containerName:
        container.show()

  if args.action == 'list':
    for container in containerArray:
      container.show()

  if args.action == 'get':
    for container in containerArray:
      if container.name == args.containerName:
        print container.get(args.property)

  if args.action == 'create':
    newContainer = Container(args.containerName)
    containerObject = newContainer.create(containerList[args.containerName])
    print 'creating'
    containerObject.show()
    if not containerObject.get('host')['ip']:
      containerHostIp=args.hostip
    else:
      containerHostIp=containerObject.get('host')['ip']
    if not args.hostport:
      containerHostPort=containerObject.get('host')['port']
    else:
      containerHostPort=args.hostport
    print 'on Container host %s %s' % (containerHostIp, containerHostPort)
    jsonObject=toJson(containerObject)
    #result = SendHTTPData(data=jsonObject,method='POST',host=containerHostIp,
    #                      port=containerHostPort,action='createContainer').send()
