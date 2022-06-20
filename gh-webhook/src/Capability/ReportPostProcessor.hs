-- | This module define the type to process reports generated by the generator
module Capability.ReportPostProcessor (
  ReportPostProcessorM (..),
) where

import As
import Core.MyError
import Error

import Core.Types

import Control.Monad.Catch (MonadThrow)
import Path

class (Monad m) => ReportPostProcessorM m where
  postProcessJavaCoreReport :: (WithError err m, As err MyError, MonadThrow m) => Path Rel File -> Path Rel Dir -> Report -> m (Path Abs File)
  postProcessHeapDumpReport :: (WithError err m, As err MyError, MonadThrow m) => Path Rel File -> Path Rel Dir -> Report -> m (Path Abs File)
  postProcessGCReport :: (WithError err m, As err MyError, MonadThrow m) => Path Rel File -> Path Rel Dir -> Report -> m (Path Abs File)
