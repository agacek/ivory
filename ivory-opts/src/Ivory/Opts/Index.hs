
--------------------------------------------------------------------------------
-- | Assert folding: add asserts expression for converting to and using indexes.
--------------------------------------------------------------------------------

module Ivory.Opts.Index
  ( ixFold
  ) where

import qualified Data.DList as D

import           Ivory.Opts.AssertFold
import           Ivory.Opts.Utils

import qualified Ivory.Language.Syntax.AST as I
import qualified Ivory.Language.Syntax.Type as I

--------------------------------------------------------------------------------

ixFold :: I.Proc -> I.Proc
ixFold = procFold expFold

--------------------------------------------------------------------------------

-- | Default expression folder that performs the recursion for an asserter.
expFold :: I.Type -> I.Expr -> [I.Expr]
expFold ty e =
  let (_, ds) = runFolderM (expFold' ty e) in
  D.toList ds

-- Here was use a custom folder (and not the expFoldDefault in AssertFold) since
-- the index checks are indepdent of control-flow (from the (x ? y : z)
-- expression) and we want to explicitly pattern-match for Ix expressions.
expFold' :: I.Type -> I.Expr -> FolderExpr ()
expFold' ty e = case e of
  I.ExpSym{}                     -> return ()
  I.ExpVar{}                     -> return ()
  I.ExpLit{}                     -> return ()
  I.ExpLabel ty' e0 _str         -> expFold' ty' e0
  I.ExpIndex tIdx eIdx tArr eArr -> do expFold' tIdx eIdx
                                       expFold' tArr eArr
  I.ExpToIx e0 maxSz             -> do insert (toIxAssert e0 maxSz)
                                       expFold' ixTy e0
  I.ExpSafeCast ty' e0           -> expFold' ty' e0
  I.ExpOp op args                -> mapM_ (expFold' $ expOpType ty op) args
  I.ExpAddrOfGlobal{}            -> return ()
  I.ExpMaxMin{}                  -> return ()

--------------------------------------------------------------------------------

-- | For toIx e :: Ix maxSz, assert
-- @
--    0 <= e < maxSz && 1 < maxSz
-- @
toIxAssert :: I.Expr -> Integer -> I.Expr
toIxAssert e maxSz = I.ExpOp I.ExpAnd
  [ I.ExpOp (I.ExpLt True ixTy)  [ lit 0, e ]
  , I.ExpOp (I.ExpLt False ixTy) [ e, lit maxSz ]
  , I.ExpOp (I.ExpLt False ixTy) [ lit 0, lit maxSz ]
  ]

--------------------------------------------------------------------------------

ixTy :: I.Type
ixTy = I.TyInt I.Int32

--------------------------------------------------------------------------------

lit :: Integer -> I.Expr
lit i = I.ExpLit (I.LitInteger i)

--------------------------------------------------------------------------------
