{-# LANGUAGE OverloadedStrings #-}
module TestMain (main) where

import Test.Syd

import Core.Types
import Has

-- | Following is only for example
-- | you must adapt it accordingly
main :: IO ()
main = sydTest $
  describe "test gh-webhook properties" $ do
    it "test property - property 1" $ True
