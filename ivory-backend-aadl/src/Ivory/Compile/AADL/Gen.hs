-- | Ivory backend for AADL descriptions of struct types

module Ivory.Compile.AADL.Gen where

import qualified Ivory.Language.Syntax as I

import qualified Data.Set as Set
import Data.List (find)

import Ivory.Compile.AADL.AST
import Ivory.Compile.AADL.Monad
import Ivory.Compile.AADL.Identifier

--------------------------------------------------------------------------------
-- | Compile a struct.
compileStruct :: I.Struct -> CompileM n ()
compileStruct def = case def of
  I.Struct n fs -> do
    ftypes <- mapM mkField fs
    writeImport "Data_Model"
    writeTypeDefinition $ DTStruct (identifier n) ftypes
  _ -> return ()

mkField :: I.Typed String -> CompileM n DTField
mkField field = do
  t <- mkType (I.tType field)
  return $ DTField (identifier (I.tValue field)) t

mkType :: I.Type -> CompileM n TypeName
mkType ty = case ty of
    I.TyVoid              -> basetype "Void"
    I.TyChar              -> basetype "Char"
    I.TyInt i             -> intSize i
    I.TyWord w            -> wordSize w
    I.TyBool              -> basetype "Boolean"
    I.TyFloat             -> basetype "Float"
    I.TyDouble            -> basetype "Double"
    I.TyStruct n          -> structType n
    I.TyConstRef _t       -> error "cannot translate TyConstRef"
    I.TyRef t             -> mkType t  -- LOSSY
    I.TyPtr _t            -> error "cannot translate TyPtr"
    I.TyArr len t         -> mkType t >>= \t' -> arrayType len t'
    I.TyCArray _t         -> error "cannot translate TyCArray"
    I.TyProc _retT _argTs -> error "cannot translate TyProc"
    I.TyOpaque            -> error "cannot translate TyOpaque"
  where
  basetype :: String -> CompileM n TypeName
  basetype t = qualTypeName "Base_Types" t

  intSize :: I.IntSize -> CompileM n TypeName
  intSize I.Int8  = basetype "Integer_8"
  intSize I.Int16 = basetype "Integer_16"
  intSize I.Int32 = basetype "Integer_32"
  intSize I.Int64 = basetype "Integer_64"

  wordSize :: I.WordSize -> CompileM n TypeName
  wordSize I.Word8  = basetype "Unsigned_8"
  wordSize I.Word16 = basetype "Unsigned_16"
  wordSize I.Word32 = basetype "Unsigned_32"
  wordSize I.Word64 = basetype "Unsigned_64"

typeImpl :: TypeName -> TypeName
typeImpl t@(DotTypeName _ _)             = t
typeImpl t@(QualTypeName "Base_Types" _) = t
typeImpl t                               = DotTypeName t "impl"

arrayType :: Int -> TypeName -> CompileM n TypeName
arrayType len basetype = do
  n <- doc_name `fmap` getTypeCtx
  writeImport n
  writeTypeCtxDefinition dtarray
  return $ QualTypeName n arraytn
  where
  dtarray = DTArray arraytn len basetype
  arraytn = identifier $ arrayTypeNameS len basetype

arrayTypeNameS :: Int -> TypeName -> String
arrayTypeNameS len basetype = "ArrTy_" ++ l ++ bts
  where
  l = show len
  bts = typeNameS basetype

typeNameS :: TypeName -> String
typeNameS (UnqualTypeName s) = "Ty" ++ s
typeNameS (QualTypeName q s) = "Ty" ++ q ++ "_" ++ s
typeNameS (DotTypeName t a) = typeNameS t ++ "_" ++ a

structType :: String -> CompileM n TypeName
structType s = do
  its <- importedTypes
  case find aux its of
    Just t@(QualTypeName m _) -> do
      writeImport m
      return t
    Just t -> return t
    Nothing -> return $ UnqualTypeName ss -- Or error...
  where
  ss = identifier s
  aux (QualTypeName _ n) = n == ss
  aux (UnqualTypeName n) = n == ss
  aux (DotTypeName t _)  = aux t

importedTypes :: CompileM n [TypeName]
importedTypes = getIModContext >>= \(m,ms) -> return (aux m ms)
  where
  aux :: I.Module -> [I.Module] -> [TypeName]
  aux a ms = concat
    [ pubStructTypeNames a m
    | m <- ms
    , (I.modName m) `Set.member` (I.modDepends a)
    ]
  pubStructTypeNames :: I.Module -> I.Module -> [TypeName]
  pubStructTypeNames a m =
    [ if a == m then UnqualTypeName (identifier n)
      else QualTypeName (identifier (I.modName m)) (identifier n)
    | I.Struct n _  <- I.public (I.modStructs m)
    ]

