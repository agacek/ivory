{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}

module Ivory.Language.IChar where

import Ivory.Language.Area
import Ivory.Language.SizeOf
import Ivory.Language.Type
import qualified Ivory.Language.Syntax as I


-- Characters ------------------------------------------------------------------

newtype IChar = IChar { getIChar :: I.Expr }

char :: Char -> IChar
char  = wrapExpr . I.ExpLit . I.LitChar

instance IvoryType IChar where
  ivoryType _ = I.TyChar

instance IvoryVar IChar where
  wrapVar    = wrapVarExpr
  unwrapExpr = getIChar

instance IvoryExpr IChar where
  wrapExpr = IChar

instance IvorySizeOf (Stored IChar) where
  sizeOfBytes _ = 1
