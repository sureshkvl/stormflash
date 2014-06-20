StormFlash = require('../lib/stormflash').StormFlash

console.log StormFlash

agent = new StormFlash
console.log agent

agent.import 'corenova-storm'
agent.run()


