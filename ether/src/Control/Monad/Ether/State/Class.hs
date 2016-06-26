{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MagicHash #-}

-- | See "Control.Monad.State.Class".

module Control.Monad.Ether.State.Class
  ( MonadState(..)
  ) where

import GHC.Prim (Proxy#)
import qualified Control.Monad.Trans as Lift

-- | See 'Control.Monad.State.MonadState'.
class Monad m => MonadState tag s m | m tag -> s where

    {-# MINIMAL state | get, put #-}

    -- | Return the state from the internals of the monad.
    get :: Proxy# tag -> m s
    get t = state t (\s -> (s, s))

    -- | Replace the state inside the monad.
    put :: Proxy# tag -> s -> m ()
    put t s = state t (\_ -> ((), s))

    -- | Embed a simple state action into the monad.
    state :: Proxy# tag -> (s -> (a, s)) -> m a
    state t f = do
        s <- get t
        let ~(a, s') = f s
        put t s'
        return a

instance {-# OVERLAPPABLE #-}
         ( Lift.MonadTrans t
         , Monad (t m)
         , MonadState tag s m
         ) => MonadState tag s (t m) where
    get t = Lift.lift (get t)
    put t = Lift.lift . put t
    state t = Lift.lift . state t