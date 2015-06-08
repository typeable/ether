{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Control.Monad.Ether.Reader
    ( EtherReaderT
    , EtherReader
    , ReaderT'
    , Reader'
    , runEtherReaderT
    , runEtherReader
    , runReaderT'
    , runReader'
    --
    , MonadEtherReader
    , etherLocal
    , etherAsk
    , etherReader
    --
    , MonadReader'
    , local'
    , ask'
    , reader'
    ) where

import Data.Proxy (Proxy(Proxy))
import Control.Monad.Trans (lift)

import Control.Ether.Core
import Control.Monad.Trans.Ether.Reader

-- for mtl instances
import qualified Control.Monad.Trans.Cont          as Trans        (ContT    , liftLocal)
import qualified Control.Monad.Trans.Except        as Trans        (ExceptT  , mapExceptT)
import qualified Control.Monad.Trans.Identity      as Trans        (IdentityT, mapIdentityT)
import qualified Control.Monad.Trans.List          as Trans        (ListT    , mapListT)
import qualified Control.Monad.Trans.Maybe         as Trans        (MaybeT   , mapMaybeT)
import qualified Control.Monad.Trans.Reader        as Trans        (ReaderT  , mapReaderT)
import qualified Control.Monad.Trans.State.Lazy    as Trans.Lazy   (StateT   , mapStateT)
import qualified Control.Monad.Trans.State.Strict  as Trans.Strict (StateT   , mapStateT)
import qualified Control.Monad.Trans.Writer.Lazy   as Trans.Lazy   (WriterT  , mapWriterT)
import qualified Control.Monad.Trans.Writer.Strict as Trans.Strict (WriterT  , mapWriterT)

class Monad m => MonadEtherReader tag r m | m tag -> r where

    etherLocal :: proxy tag -> (r -> r) -> m a -> m a

    etherAsk :: proxy tag -> m r
    etherAsk proxy = etherReader proxy id

    etherReader :: proxy tag -> (r -> a) -> m a
    etherReader proxy f = fmap f (etherAsk proxy)

type MonadReader' r = MonadEtherReader r r

local' :: forall m r a . MonadReader' r m => (r -> r) -> m a -> m a
local' = etherLocal (Proxy :: Proxy r)

ask' :: forall m r . MonadReader' r m => m r
ask' = etherAsk (Proxy :: Proxy r)

reader' :: forall m r a . MonadReader' r m => (r -> a) -> m a
reader' = etherReader (Proxy :: Proxy r)

instance {-# OVERLAPPING #-} (Monad m, EtherTagless tag m)
  => MonadEtherReader tag r (EtherReaderT tag r m) where
    etherAsk proxy = etherReaderT proxy return
    etherLocal proxy f m = etherReaderT proxy (runEtherReaderT proxy m . f)

instance MonadEtherReader tag r m => MonadEtherReader tag r (EtherReaderT tag' r' m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = mapEtherReaderT Proxy . etherLocal proxy

-- Instances for mtl transformers

instance MonadEtherReader tag r m => MonadEtherReader tag r (Trans.ContT r' m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = Trans.liftLocal (etherAsk proxy) (etherLocal proxy)

instance MonadEtherReader tag r m => MonadEtherReader tag r (Trans.ExceptT e m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = Trans.mapExceptT . etherLocal proxy

instance MonadEtherReader tag r m => MonadEtherReader tag r (Trans.IdentityT m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = Trans.mapIdentityT . etherLocal proxy

instance MonadEtherReader tag r m => MonadEtherReader tag r (Trans.ListT m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = Trans.mapListT . etherLocal proxy

instance MonadEtherReader tag r m => MonadEtherReader tag r (Trans.MaybeT m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = Trans.mapMaybeT . etherLocal proxy

instance MonadEtherReader tag r m => MonadEtherReader tag r (Trans.ReaderT r' m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = Trans.mapReaderT . etherLocal proxy

instance MonadEtherReader tag r m => MonadEtherReader tag r (Trans.Lazy.StateT s m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = Trans.Lazy.mapStateT . etherLocal proxy

instance MonadEtherReader tag r m => MonadEtherReader tag r (Trans.Strict.StateT s m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = Trans.Strict.mapStateT . etherLocal proxy

instance (Monoid w, MonadEtherReader tag r m) => MonadEtherReader tag r (Trans.Lazy.WriterT w m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = Trans.Lazy.mapWriterT . etherLocal proxy

instance (Monoid w, MonadEtherReader tag r m) => MonadEtherReader tag r (Trans.Strict.WriterT w m) where
    etherAsk proxy = lift (etherAsk proxy)
    etherLocal proxy = Trans.Strict.mapWriterT . etherLocal proxy
