{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE OverloadedStrings #-}

module Json where

import Test.Tasty
import Test.Tasty.QuickCheck
import Test.Tasty.HUnit

import Control.Lens (set, view, (&))
import Data.Aeson
import Data.HashMap.Strict (fromList)
import Data.Id
import Data.List1
import Data.Monoid
import Data.String
import Gundeck.Types.BulkPush
import Gundeck.Types.Notification
import Gundeck.Types.Push


tests :: TestTree
tests = testGroup "JSON"
    [ testProperty "push/recipient" $
        forAll genRecipient serialiseOkProp

    , testGroup "BulkPush"
        [ testCase "PushTarget example" $ do
              let serialized = "{\"connId\":\"nJ\",\"userId\":\"09178cd7-3190-45ec-95aa-695edbb03960\"}"
                  typed = PushTarget (read "09178cd7-3190-45ec-95aa-695edbb03960") (ConnId "nJ")
              assertEqual "" (decode serialized) (Just typed)
        , testCase "BulkPushRequest example" $ do
              let serialized = "{\"bulkpush-req\":[{\"notification\":{\"payload\":[{\"Rk\":\"o\"},{\"n\":\"uy\"}],\"transient\":true,\"id\":\"d8f6c42e-f8da-4e7b-99e7-db66eccf8da1\"},\"targets\":[{\"connId\":\"88\",\"userId\":\"7d94d3f0-f853-41d3-bd25-eb17c8f72f6e\"},{\"connId\":\"v\",\"userId\":\"10158f18-3350-41c5-9eb4-374dee978e05\"}]},{\"notification\":{\"payload\":[{}],\"transient\":false,\"id\":\"8d3111d1-d010-47e6-b5db-d81cfbe8b0d4\"},\"targets\":[{\"connId\":\"nJ\",\"userId\":\"09178cd7-3190-45ec-95aa-695edbb03960\"}]}]}"
                  typed = Just (BulkPushRequest {fromBulkPushRequest = [(Notification {ntfId = (read "d8f6c42e-f8da-4e7b-99e7-db66eccf8da1"), ntfTransient = True, ntfPayload = list1 (fromList [("Rk",String "o")]) [fromList [("n",String "uy")]]},[PushTarget {ptUserId = read "7d94d3f0-f853-41d3-bd25-eb17c8f72f6e", ptConnId = ConnId {fromConnId = "88"}},PushTarget {ptUserId = read "10158f18-3350-41c5-9eb4-374dee978e05", ptConnId = ConnId {fromConnId = "v"}}]),(Notification {ntfId = read "8d3111d1-d010-47e6-b5db-d81cfbe8b0d4", ntfTransient = False, ntfPayload = list1 (fromList []) []},[PushTarget {ptUserId = read "09178cd7-3190-45ec-95aa-695edbb03960", ptConnId = ConnId {fromConnId = "nJ"}}])]})
              assertEqual "" (decode serialized) (Just typed)
        , testCase "BulkPushResponse example" $ do
              let serialized = "{\"bulkpush-resp\":[{\"status\":\"PushStatusGone\",\"notifId\":\"f2c218cf-6399-47fb-8d7b-726ed599af91\",\"target\":{\"connId\":\"\",\"userId\":\"5b099991-364a-425d-91af-9b8e51ac2956\"}},{\"status\":\"PushStatusOk\",\"notifId\":\"d8e8d19a-6788-4180-afcd-bf84395f4cf6\",\"target\":{\"connId\":\"Lf\",\"userId\":\"cccc316f-eaad-4d55-9798-3fd8b431106e\"}}]}"
                  typed = BulkPushResponse {fromBulkPushResponse = [(read "f2c218cf-6399-47fb-8d7b-726ed599af91",PushTarget {ptUserId = read "5b099991-364a-425d-91af-9b8e51ac2956", ptConnId = ConnId {fromConnId = ""}},PushStatusGone),(read "d8e8d19a-6788-4180-afcd-bf84395f4cf6",PushTarget {ptUserId = read "cccc316f-eaad-4d55-9798-3fd8b431106e", ptConnId = ConnId {fromConnId = "Lf"}},PushStatusOk)]}
              assertEqual "" (decode serialized) (Just typed)
        ]

    , testProperty "BulkPushRequest roundtrip" .
        forAll genBulkPushRequest $ \req -> eitherDecode (encode req) == Right req
    , testProperty "BulkPushResponse roundtrip" .
        forAll genBulkPushResponse $ \resp -> eitherDecode (encode resp) == Right resp
    ]

serialiseOkProp :: Recipient -> Property
serialiseOkProp r = property $
        let r' = decode (encode r)
        in   (view recipientId       <$> r') == Just (view recipientId r)
          && (view recipientRoute    <$> r') == Just (view recipientRoute r)
          && (view recipientClients  <$> r') == Just (view recipientClients r)
          && (view recipientFallback <$> r') == Just (view recipientFallback r)

-----------------------------------------------------------------------------
-- Randomness

-- TODO: not sure if these exist elsewhere?  or should be moved elsewhere?
-- TODO: genObject, genAlphaNum are not very exhaustive.

genRecipient :: Gen Recipient
genRecipient = do
    r <- recipient <$> arbitrary <*> elements [ RouteAny, RouteDirect, RouteNative ]
    c <- arbitrary
    f <- arbitrary
    return $ r & set recipientFallback f & set recipientClients c

genBulkPushRequest :: Gen BulkPushRequest
genBulkPushRequest = BulkPushRequest <$>
    listOf ((,) <$> genNotification <*> listOf genPushTarget)

genBulkPushResponse :: Gen BulkPushResponse
genBulkPushResponse = BulkPushResponse <$>
    listOf ((,,) <$> arbitrary <*> genPushTarget <*> elements [minBound..])

genNotification :: Gen Notification
genNotification = Notification <$> arbitrary <*> arbitrary <*> (list1 <$> genobj <*> listOf genobj)
  where
    genobj = scale (`div` 3) genObject

genPushTarget :: Gen PushTarget
genPushTarget = PushTarget <$> arbitrary <*> (ConnId <$> genAlphaNum)

genObject :: Gen Object
genObject = fromList <$> listOf ((,) <$> genAlphaNum <*> (String <$> genAlphaNum))

genAlphaNum :: IsString s => Gen s
genAlphaNum = fromString <$> listOf (elements (['a'..'z'] <> ['A'..'Z'] <> ['0'..'9']))
