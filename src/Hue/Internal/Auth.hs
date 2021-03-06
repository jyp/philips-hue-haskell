-- |
-- Module: Hue.Internal.Auth
-- Copyright: (c) 2018 Thomas Smith
-- License: BSD3
-- Maintainer: Thomas Smith <tnsmith@live.nl>
-- Stability: experimental
--
-- Everything needed to authenticate with the Hue Bridge
-- and store the credentials.
--
-- This is an internal module.
--
-- Please use "Hue.Auth" instead.
module Hue.Internal.Auth where

import Network.HostName (getHostName)

import qualified Data.Text as Text

import Control.Concurrent (threadDelay)
import Control.Monad.Loops (untilJust)
import Control.Monad.Except

import Hue.Internal
import Hue.Internal.Request

-- | The authentication request.
--
-- Send this request after the user pushes the bridge button to get fresh credentials.
--
-- See also: 'registerApp'
authenticate :: HueDeviceType -> Hue HueCredentials
authenticate d = post (Body d) ParseResult api


-- | Register the application with the bridge
--
-- This function waits until the user pushes the bridge button
-- and registers with the current hostname as device name.
registerApp :: Hue HueCredentials
registerApp = do
  liftIO $ putStrLn "Push the button on your bridge."
  untilJust $ do
    liftIO $ threadDelay 1000000
    tryRegisterWithBridge

  where
    tryRegisterWithBridge :: Hue (Maybe HueCredentials)
    tryRegisterWithBridge = (do
        deviceName <- liftIO getHostName
        Just <$> (authenticate $ HueDeviceType $ Text.pack deviceName)
      ) `catchError` handleApiException

    handleApiException :: (MonadIO m, MonadError HueApiException m) => HueApiException -> m (Maybe a)
    handleApiException err@(HueApiException []) = throwError err
    handleApiException err@(HueApiException ((HueError code _):_))
      | buttonNotYetPushed = pure Nothing
      | otherwise          = throwError err
      where
        buttonNotYetPushed = code == 101
