{-# OPTIONS_GHC -fno-warn-unticked-promoted-constructors #-}

{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MagicHash #-}

module Control.Monad.Ether.Reader.Flatten
  ( runReader
  , runReaderT
  ) where

import qualified Control.Monad.Trans.Lift.Local  as Lift

import Data.Functor.Identity
import Control.Monad.Ether.Reader.Class as C
import Control.Monad.Trans.Ether.Dispatch
import qualified Control.Monad.Trans.Reader as T
import Control.Lens
import Control.Ether.Flatten

data FLATTEN (ts :: [k])

type FlattenT ts r = Dispatch (FLATTEN ts) (T.ReaderT r)

reflatten
  :: forall tagsOld tagsNew r m a
   . FlattenT tagsOld r m a
  -> FlattenT tagsNew r m a
reflatten = repack
{-# INLINE reflatten #-}

instance
    ( Monad m, Monad (trans m)
    , Lift.MonadTrans trans
    , Lift.LiftLocal trans
    , C.MonadReader tag r m
    ) => C.MonadReader tag r (Dispatch (FLATTEN '[]) trans m)
  where
    ask t = Lift.lift (ask t)
    local t = Lift.liftLocal (ask t) (local t)

instance
    ( Monad m, HasLens tag payload r
    , trans ~ T.ReaderT payload
    ) => C.MonadReader tag r (Dispatch (FLATTEN (tag ': tags)) trans m)
  where
    ask t = pack $ view (lensOf t)
    local t f = pack . T.local (over (lensOf t) f) . unpack

instance {-# OVERLAPPABLE #-}
    ( Monad m
    , C.MonadReader tag r (Dispatch (FLATTEN tags) trans m)
    , trans ~ T.ReaderT payload
    ) => C.MonadReader tag r (Dispatch (FLATTEN (t ': tags)) trans m)
  where
    ask t = reflatten @tags @(t ': tags) (C.ask t)
    {-# INLINE ask #-}
    local t f
      = reflatten @tags @(t ': tags)
      . C.local t f
      . reflatten @(t ': tags) @tags
    {-# INLINE local #-}

runReaderT
  :: FlattenT tags (Product tags as) m a
  -> Product tags as
  -> m a
runReaderT m = T.runReaderT (unpack m)

runReader
  :: FlattenT tags (Product tags as) Identity a
  -> Product tags as
  -> a
runReader m = T.runReader (unpack m)
