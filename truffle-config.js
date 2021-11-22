/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

 const HDWalletProvider = require('@truffle/hdwallet-provider');
 // const infuraKey = process.env.infuraId;
 
 var privKey = process.env.privKey;
 var etherscanApiKey = process.env.etherscanApiKey;
 var bscscanApiKey = process.env.bscscanApiKey;
 var hecoinfoApiKey = process.env.hecoinfoApiKey;
 var ftmscanApiKey = process.env.ftmscanApiKey;
 var polygonscanApiKey = process.env.polygonscanApiKey;
 
 //
 // const fs = require('fs');
 // const mnemonic = fs.readFileSync(".secret").toString().trim();
 
 module.exports = {
 
   // contracts_build_directory: "./build",
 
   /**
    * Networks define how you connect to your ethereum client and let you set the
    * defaults web3 uses to send transactions. If you don't specify one truffle
    * will spin up a development blockchain for you on port 9545 when you
    * run `develop` or `test`. You can ask a truffle command to use a specific
    * network from the command line, e.g
    *
    * $ truffle test --network <network-name>
    */
 
   networks: {
     bsctest: {
       provider: function () {
         return new HDWalletProvider(privKey, "https://data-seed-prebsc-2-s2.binance.org:8545/");
       },
       network_id: 97,
       confirmations: 0,
       gasPrice: 10000000000,
       timeoutBlocks: 200,
       skipDryRun: true
     },
     bsclive: {
       provider: function () {
         return new HDWalletProvider(privKey, "https://bsc-dataseed1.binance.org");
       },
       network_id: 56,
       confirmations: 1,
       gasPrice: 5000000000,
       timeoutBlocks: 200,
       gasPrice: 6000000000,
       skipDryRun: true
     },
    },
     
 
   plugins: ["solidity-coverage", "truffle-plugin-verify"],
 
   api_keys: {
     etherscan: etherscanApiKey,
     bscscan: bscscanApiKey,
     hecoinfo: hecoinfoApiKey,
     ftmscan: ftmscanApiKey,
     polygonscan: polygonscanApiKey,
   },
 
   // Set default mocha options here, use special reporters etc.
   mocha: {
     timeout: false
   },
 
   // Configure your compilers
   compilers: {
     solc: {
       version: "0.6.12",    // Fetch exact version from solc-bin (default: truffle's version)
       // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
       settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: "istanbul"
       }
     }
   },
 
   // Truffle DB is currently disabled by default; to enable it, change enabled: false to enabled: true
   //
   // Note: if you migrated your contracts prior to enabling this field in your Truffle project and want
   // those previously migrated contracts available in the .db directory, you will need to run the following:
   // $ truffle migrate --reset --compile-all
 
   db: {
     enabled: false
   }
 };
 