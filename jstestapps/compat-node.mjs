import { createRequire } from 'module';
                                                                                                                                                              
// Node.js currently does not support loading native module
// using ES6 module syntax
const require = createRequire(import.meta.url);
const nccc = require("node-nccc");
const debug_prefix = require("nccc-debug-prefix");
 
export default {
    nccc: nccc,
    debug_prefix: debug_prefix
};

