{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# OPTIONS_GHC -fno-specialise #-}

module Cerra.Lending.Utils.Utils
(module Cerra.Lending.Utils.Utils)
where

import Ledger (AssetClass, Value)
import Data.Maybe (fromJust)
import Plutus.V2.Ledger.Api
  ( Value (Value),
    Address,
    PubKeyHash,
    TokenName (TokenName),
    CurrencySymbol,
    TxOutRef (TxOutRef),
    TxInfo,
    TxInInfo,
    ValidatorHash,
    ScriptContext,
    TxId (getTxId),
    txInInfoResolved,
    TxInfo(txInfoInputs),
    adaSymbol,
    adaToken,
    TxOut
  )
import Ledger.Ada (getLovelace, fromValue)
import Plutus.V2.Ledger.Contexts
  ( txInfoOutputs,
    txOutAddress,
    findOwnInput,
    txOutValue
  )
import Ledger.Value
  ( AssetClass (..),
    assetClass,
    currencySymbol,
    tokenName,
    getValue,
    assetClassValue
  )
import Cerra.Lending.Utils.OnChainUtils (integerToBS)
import Ledger.Address (pubKeyHashAddress, PaymentPubKeyHash (PaymentPubKeyHash))
import Ledger (toValidatorHash)
import Ledger.Interval (Interval, UpperBound (..), LowerBound (..), Extended(Finite), ivTo, ivFrom)
import Cerra.Lending.Utils.OnChainUtils (scriptDatumExists)
import Text.Hex (Text, decodeHex)
import qualified PlutusTx.AssocMap as Map
import PlutusTx.Prelude
  ( error,
    Bool(..),
    Maybe(..),
    fst,
    (<>),
    ($),
    (&&),
    (||),
    (==),
    (/=),
    Bool,
    Integer,
    (+),
    (-),
    sha2_256
  )

cerraSymbol :: Text.Hex.Text
cerraSymbol = "46f987f7ed1886ba771b077c3ed5bbf3df158f54e0e3fa88d3d1e46e"

{-# INLINEABLE cerraName #-}
cerraName :: TokenName
cerraName = tokenName $ fromJust $ decodeHex "744345525241"

{-# INLINEABLE cerraCurrencySymbol #-}
cerraCurrencySymbol :: CurrencySymbol
cerraCurrencySymbol = currencySymbol $ fromJust $ decodeHex cerraSymbol

{-# INLINEABLE cerraAssetClass #-}
cerraAssetClass :: AssetClass
cerraAssetClass = assetClass cerraCurrencySymbol cerraName

oracleFactory :: Text.Hex.Text
oracleFactory = "089eb57344dcfa1d2d82749566f27aa5c072194d11a261d6e66f33cc"

{-# INLINEABLE oracleFactoryName #-}
oracleFactoryName :: TokenName
oracleFactoryName = tokenName $ fromJust $ decodeHex "4c4943454e5345"

{-# INLINEABLE oracleFactorySymbol #-}
oracleFactorySymbol :: CurrencySymbol
oracleFactorySymbol = currencySymbol $ fromJust $ decodeHex oracleFactory

{-# INLINEABLE oracleFactoryAssetClass #-}
oracleFactoryAssetClass :: AssetClass
oracleFactoryAssetClass = assetClass oracleFactorySymbol oracleFactoryName

{-# INLINEABLE treasuryPubKeyHash #-}
treasuryPubKeyHash :: PubKeyHash
treasuryPubKeyHash = "ec0222eebabb0975456b44bc23dd9baf16bbec620ab4fd10b5dec5c9"

{-# INLINEABLE treasuryPaymentPubKeyHash #-}
treasuryPaymentPubKeyHash :: PaymentPubKeyHash
treasuryPaymentPubKeyHash = PaymentPubKeyHash treasuryPubKeyHash

{-# INLINEABLE treasuryAddress #-}
treasuryAddress :: Address
treasuryAddress = pubKeyHashAddress treasuryPaymentPubKeyHash Nothing

{-# INLINEABLE lendingNFTOf #-}
lendingNFTOf :: Value -> CurrencySymbol -> AssetClass
lendingNFTOf (Value v) nftSymbol = case Map.lookup nftSymbol v of
  Nothing -> error ()
  Just i -> case [o | o@(_, am) <- Map.toList i, am == 1] of
    [(tn, _)] -> assetClass nftSymbol tn
    _ -> error ()

{-# INLINEABLE getCS #-}
getCS :: (a, b, c) -> a
getCS (a,_,_) = a

{-# INLINEABLE getTN #-}
getTN :: (a, b, c) -> b
getTN (_,b,_) = b

{-# INLINEABLE getAmount #-}
getAmount :: (a, b, c) -> c
getAmount (_,_,c) = c

{-# INLINEABLE mkNftTokenName #-}
mkNftTokenName :: TxOutRef -> TokenName
mkNftTokenName (TxOutRef refHash refIdx) = tName
  where
    tName :: TokenName
    tName = TokenName $ sha2_256 $ getTxId refHash <> integerToBS refIdx

{-# INLINABLE getContractInput #-}
getContractInput :: TxInfo -> TxOut
getContractInput info = txInInfoResolved contractInput
  where
    !txInputs = txInfoInputs info

    contractInput :: TxInInfo
    !contractInput = case [i | i <- txInputs, scriptDatumExists (txInInfoResolved i)] of
      [i] -> i
      _ -> error ()

{-# INLINABLE getValidateContractOutput #-}
getValidateContractOutput :: TxInfo -> ValidatorHash -> TxOut
getValidateContractOutput info vh = if (fromJustCustom $ toValidatorHash $ txOutAddress scOutput) == vh
  then scOutput
  else error ()
  where
    txOutputs :: [TxOut]
    txOutputs = txInfoOutputs info

    scOutput :: TxOut
    !scOutput = case [o | o <- txOutputs, scriptDatumExists o] of
      [o] -> o
      _ -> error ()

{-# INLINABLE getContractOutput #-}
getContractOutput :: TxInfo -> TxOut
getContractOutput info = contractOutput
  where
    txOutputs :: [TxOut]
    txOutputs = txInfoOutputs info

    contractOutput :: TxOut
    !contractOutput = case [o | o <- txOutputs, scriptDatumExists o] of
      [o] -> o
      _ -> error ()

{-# INLINABLE assetAmount #-}
assetAmount :: AssetClass -> Integer -> Integer
assetAmount asset amount = case asset == adaCoin of
  True -> amount - 2_000_000
  False -> amount

{-# INLINABLE assetAmountTwoCurrencies #-}
assetAmountTwoCurrencies :: AssetClass -> Integer -> Integer
assetAmountTwoCurrencies asset amount = case asset == adaCoin of
  True -> amount - 4_000_000
  False -> amount

{-# INLINABLE lovelaceAmount #-}
lovelaceAmount :: AssetClass -> Value -> Integer
lovelaceAmount asset val = case asset == adaCoin of
  True -> 2_000_000
  False -> getLovelace (fromValue val)

{-# INLINABLE lovelaceAmountTwoCurrencies #-}
lovelaceAmountTwoCurrencies :: AssetClass -> Integer -> AssetClass -> Integer -> Integer -> Integer
lovelaceAmountTwoCurrencies asset1 amount1 asset2 amount2 adaBalance =
  -- scenario where both assets are ADA is impossible
  if asset1 == adaCoin then adaBalance - amount1
  else if asset2 == adaCoin then adaBalance - amount2
  else adaBalance

{-# INLINABLE assetLength #-}
assetLength :: AssetClass -> Integer -> Integer
assetLength asset count = case asset == adaCoin of
  True -> count + 1
  False -> count

{-# INLINABLE assetLengthTwoCurrencies #-}
assetLengthTwoCurrencies :: AssetClass -> AssetClass -> Integer -> Integer
assetLengthTwoCurrencies asset1 asset2 count = case (asset1 == adaCoin) || (asset2 == adaCoin) of
  True -> count + 1
  False -> count

{-# INLINABLE validateOutputAddress #-}
validateOutputAddress :: TxOut -> Address -> TxOut
validateOutputAddress output address = case address == txOutAddress output of
  True -> output
  False -> error ()

{-# INLINABLE factoryNFT #-}
factoryNFT :: [(CurrencySymbol, TokenName, Integer)] -> AssetClass -> AssetClass
factoryNFT flattenVal asset = case [c | c <- flattenVal,
  adaSymbol /= getCS c
  && fst (unAssetClass asset) /= getCS c
  && getAmount c == 1] of
    [c] -> assetClass (getCS c) (getTN c)
    _ -> error ()

{-# INLINABLE factoryNFTTwoCurrencies #-}
factoryNFTTwoCurrencies :: [(CurrencySymbol, TokenName, Integer)] -> AssetClass -> AssetClass -> AssetClass
factoryNFTTwoCurrencies flattenVal asset1 asset2 = case [c | c <- flattenVal,
  adaSymbol /= getCS c
  && fst (unAssetClass asset1) /= getCS c
  && fst (unAssetClass asset2) /= getCS c
  && getAmount c == 1] of
    [c] -> assetClass (getCS c) (getTN c)
    _ -> error ()

{-# INLINABLE factoryNFTUnknownState #-}
factoryNFTUnknownState :: [(CurrencySymbol, TokenName, Integer)] -> AssetClass -> AssetClass -> AssetClass
factoryNFTUnknownState flattenVal assetOne assetTwo = case [c | c <- flattenVal,
  adaSymbol /= getCS c
  && fst (unAssetClass assetOne) /= getCS c
  && fst (unAssetClass assetTwo) /= getCS c
  && getAmount c == 1] of
    [c] -> assetClass (getCS c) (getTN c)
    _ -> error ()

{-# INLINABLE isNFTExists #-}
isNFTExists :: [(CurrencySymbol, TokenName, Integer)] -> CurrencySymbol -> Bool
isNFTExists flattenVal symbol = case [c | c <- flattenVal,
  symbol == getCS c
  && getAmount c == 1] of
    [_] -> True
    _ -> False

isNFTBurned :: [(CurrencySymbol, TokenName, Integer)] -> CurrencySymbol -> Bool
isNFTBurned flattenVal symbol = case [c | c <- flattenVal,
  symbol == getCS c
  && getAmount c == -1] of
    [_] -> True
    _ -> False

{-# INLINABLE ownContractInput #-}
ownContractInput :: ScriptContext -> TxOut
ownContractInput ctx = case findOwnInput ctx of
   Just txInInfo -> txInInfoResolved txInInfo
   _ -> error ()

{-# INLINABLE ownContractOutput #-}
ownContractOutput :: TxInfo -> Address -> TxOut
ownContractOutput info ownAddress = ownOutput
   where
     txOutputs :: [TxOut]
     !txOutputs = txInfoOutputs info

     ownOutput :: TxOut
     !ownOutput = case [o | o <- txOutputs, ownAddress == txOutAddress o] of
       [o] -> o
       _ -> error ()

{-# INLINEABLE validateFee #-}
validateFee :: Address -> Integer -> TxInfo -> Bool
validateFee tAddress _ info =
    let treasuryVal = case [o | o <- txInfoOutputs info, tAddress == txOutAddress o] of
          [o] -> txOutValue o
          _ -> error ()

        treasuryLovelaceOut = getLovelace (fromValue treasuryVal)

     in if treasuryLovelaceOut == 2_000_000 then True
        else False

{-# INLINEABLE getUpperBound #-}
getUpperBound :: Interval a -> a
getUpperBound interval = case ivTo interval of
    UpperBound (Finite value) _isInclusive -> fromJust (Just value)
    _ -> error ()

{-# INLINEABLE getLowerBound #-}
getLowerBound :: Interval a -> a
getLowerBound interval = case ivFrom interval of
    LowerBound (Finite value) _isInclusive -> fromJust (Just value)
    _ -> error ()

{-# INLINEABLE fromJustCustom #-}
fromJustCustom :: Maybe a -> a
fromJustCustom a = case a of
    Just b -> b
    _ -> error ()

{-# INLINEABLE unitValue #-}
unitValue :: AssetClass -> Value
unitValue c = assetClassValue c 1

{-# INLINEABLE isUnity #-}
isUnity :: Value -> AssetClass -> Bool
isUnity v c = Map.lookup curr (getValue v) == Just (Map.fromList [(tok, 1)])
  where (curr, tok) = unAssetClass c

{-# INLINEABLE adaCoin #-}
adaCoin :: AssetClass
adaCoin = assetClass adaSymbol adaToken

{-# INLINEABLE symbolOf #-}
symbolOf :: AssetClass -> CurrencySymbol
symbolOf (AssetClass (cs, _)) = cs

{-# INLINEABLE tokenNameOf #-}
tokenNameOf :: AssetClass -> TokenName
tokenNameOf (AssetClass (_, tn)) = tn