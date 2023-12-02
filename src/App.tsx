import React, { ReactElement, useState } from 'react';
import { StacksTestnet, StacksMainnet } from '@stacks/network';
import {
  callReadOnlyFunction,
  getAddressFromPublicKey,
  uintCV,
  cvToValue,
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  FungibleConditionCode,
  makeStandardSTXPostCondition,
  bufferCVFromString,
} from '@stacks/transactions';
import {
  AppConfig,
  FinishedAuthData,
  showConnect,
  UserSession,
  openSignatureRequestPopup
} from '@stacks/connect';
import { verifyMessageSignatureRsv } from '@stacks/encryption';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ExternalLink } from './external-link';
import { ArrowRight } from 'lucide-react';
import { truncateAddress } from './lib/utils';

function App(): ReactElement {
  const [address, setAddress] = useState('');
  const [isSignatureVerified, setIsSignatureVerified] = useState(false);
  const [hasFetchedReadOnly, setHasFetchedReadOnly] = useState(false);

  // Initialize your app configuration and user session here
  const appConfig = new AppConfig(['store_write', 'publish_data']);
  const userSession = new UserSession({ appConfig });

  const message = 'Howdy, Hiro Hacks!';
  const network = new StacksMainnet();

  const [keysAmount, setKeysAmount] = useState(0);
  const _contractAddress = 'SP000000000000000000002Q6VF78';
  const _contractName = 'keys';

  // Define your authentication options here
  const authOptions = {
    userSession,
    appDetails: {
      name: 'Reds App',
      icon: 'src/favicon.svg'
    },
    onFinish: (data: FinishedAuthData) => {
      // Handle successful authentication here
      let userData = data.userSession.loadUserData();
      setAddress(userData.profile.stxAddress.testnet); // or .testnet for testnet, or .mainnet for mainnet
    },
    onCancel: () => {
      // Handle authentication cancellation here
    },
    redirectTo: '/'
  };

  const connectWallet = () => {
    showConnect(authOptions);
  };

  const disconnectWallet = () => {
    if (userSession.isUserSignedIn()) {
      userSession.signUserOut('/');
      setAddress('');
    }
  };

  const fetchReadOnly = async (senderAddress: string) => {
    // Define your contract details here
    const contractAddress = 'SP000000000000000000002Q6VF78';
    const contractName = 'pox-3';
    const functionName = 'is-pox-active';

    const functionArgs = [uintCV(10)];

    try {
      const result = await callReadOnlyFunction({
        network,
        contractAddress,
        contractName,
        functionName,
        functionArgs,
        senderAddress
      });
      setHasFetchedReadOnly(true);
      console.log(cvToValue(result));
    } catch (error) {
      console.error('Error fetching read-only function:', error);
    }
  };

  const signMessage = () => {
    if (userSession.isUserSignedIn()) {
      openSignatureRequestPopup({
        message,
        network,
        onFinish: async ({ publicKey, signature }) => {
          // Verify the message signature using the verifyMessageSignatureRsv function
          const verified = verifyMessageSignatureRsv({
            message,
            publicKey,
            signature
          });
          if (verified) {
            // The signature is verified, so now we can check if the user is a keyholder
            setIsSignatureVerified(true);
            console.log(
              'Address derived from public key',
              getAddressFromPublicKey(publicKey, network.version)
            );
          }
        }
      });
    }
  };

  const buyKeys = async () => {
    if (!userSession.isUserSignedIn()) {
      console.log("User not signed in");
      return;
    }

    const userData = userSession.loadUserData();
    const senderKey = userData.profile.stxAddress.testnet;
    const contractAddress = _contractAddress;
    const contractName = _contractName;
    const txOptions = {
      contractAddress,
      contractName,
      functionName: 'buy-keys',
      functionArgs: [bufferCVFromString(subject), uintCV(keysAmount)], //[contractPrincipalCV(subject), uintCV(keysAmount)] TODO: define subject
      senderKey,
      validateWithAbi: true,
      network,
      postConditions: [],
      anchorMode: AnchorMode.Any,
      onFinish: (data: { txId: any; }) => { //TODO: fix txId: any
          console.log('Transaction ID:', data.txId);
          console.log('Finished buying keys');
      },
    };

    try {
      await makeContractCall(txOptions);
    } catch (error) {
      console.error('Error buying keys:', error);
    }
  };

  // const sellKeys = async () => {
  //   if (!userSession.isUserSignedIn()) {
  //     console.log("User not signed in");
  //     return;
  //   }

  //   const userData = userSession.loadUserData();
  //   const senderAddress = userData.profile.stxAddress.testnet;
  //   const contractAddress = _contractAddress;
  //   const contractName = _contractName;

  //   try {
  //     await makeContractCall({
  //       network,
  //       contractAddress,
  //       contractName,
  //       functionName: 'sell-keys',
  //       functionArgs: [contractPrincipalCV(subject), uintCV(keysAmount)],
  //       senderAddress,
  //       postConditions: [],
  //       onFinish: (data) => {
  //         console.log('Transaction ID:', data.txId);
  //         console.log('Finished selling keys');
  //       },
  //     });
  //   } catch (error) {
  //     console.error('Error selling keys:', error);
  //   }
  // };

  return (
    <div className="flex items-center justify-center min-h-screen">
      <div className="mx-auto max-w-2xl px-4">
        <div className="rounded-lg border bg-background p-8">
          <h1 className="mb-2 text-lg font-semibold">Welcome to Red's Hiro Hacks project!</h1>
          <p className="leading-normal text-muted-foreground">
            This webapp is based on an open source starter template:{' '}
            <ExternalLink href="https://docs.hiro.so/stacks.js/overview">
              Stacks.js
            </ExternalLink>{' '}
          </p>

          <div className="mt-4 flex flex-col items-start space-y-2">
            {userSession.isUserSignedIn() ? (
              <div className="flex justify-between w-full">
                <Button
                  onClick={disconnectWallet}
                  variant="link"
                  className="h-auto p-0 text-base"
                >
                  1. Disconnect wallet
                  <ArrowRight size={15} className="ml-1" />
                </Button>
                {address && <span>{truncateAddress(address)}</span>}
              </div>
            ) : (
              <Button
                onClick={connectWallet}
                variant="link"
                className="h-auto p-0 text-base"
              >
                1. Connect your wallet
                <ArrowRight size={15} className="ml-1" />
              </Button>
            )}
            <div className="flex justify-between w-full">
              <Button
                onClick={signMessage}
                variant="link"
                className="h-auto p-0 text-base text-neutral-500"
              >
                2. Sign a message
                <ArrowRight size={15} className="ml-1" />
              </Button>
              {isSignatureVerified && <span>{message}</span>}
            </div>

            {userSession.isUserSignedIn() ? (
              <div className="flex justify-between w-full">
                <Button
                  onClick={() => fetchReadOnly(address)}
                  variant="link"
                  className="h-auto p-0 text-base"
                >
                  3. Read from a smart contract
                  <ArrowRight size={15} className="ml-1" />
                </Button>
                {hasFetchedReadOnly && (
                  <span>
                    <Badge className="text-orange-500 bg-orange-100">
                      Success
                    </Badge>
                  </span>
                )}
              </div>
            ) : (
              <div className="flex justify-between w-full">
                <Button
                  variant="link"
                  className="disabled h-auto p-0 text-base"
                >
                  3. Read from a smart contract
                  <ArrowRight size={15} className="ml-1" />
                </Button>
              </div>
            )}
            <div>
              <input
                type="number"
                value={keysAmount}
                onChange={(e) => setKeysAmount(Number(e.target.value))}
                placeholder="Enter amount of keys"
              />
              <Button onClick={buyKeys}>Buy Keys</Button>
              {/* <Button onClick={sellKeys}>Sell Keys</Button> */}
            </div>
          </div>
        </div>
      </div>
    </div>
  );

  // return (
  //   <div className="text-center">
  //     <h1 className="text-xl">Friend.tech</h1>
  //     <div>
  //       <button onClick={disconnectWallet}>Disconnect Wallet</button>
  //     </div>
  //     <div>
  //       <p>
  //         {address} is {isKeyHolder ? '' : 'not'} a key holder
  //       </p>
  //       <div>
  //         <input
  //           type="text"
  //           id="address"
  //           name="address"
  //           placeholder="Enter address"
  //         />
  //         <button onClick={() => checkIsKeyHolder(address)}>
  //           Check Key Holder
  //         </button>
  //         <div>
  //           <p>Key Holder Check Result: {isKeyHolder ? 'Yes' : 'No'}</p>
  //         </div>
  //       </div>
  //     </div>
  //     <div>
  //       Sign this message: <button onClick={signMessage}>Sign</button>
  //     </div>
  //   </div>
  // );
}

export default App;
