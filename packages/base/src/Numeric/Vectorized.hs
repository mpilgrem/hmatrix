-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.Vectorized
-- Copyright   :  (c) Alberto Ruiz 2007-15
-- License     :  BSD3
-- Maintainer  :  Alberto Ruiz
-- Stability   :  provisional
--
-- Low level interface to vector operations.
--
-----------------------------------------------------------------------------

module Numeric.Vectorized (
    sumF, sumR, sumQ, sumC, sumI,
    prodF, prodR, prodQ, prodC, prodI,
    FunCodeS(..), toScalarR, toScalarF, toScalarC, toScalarQ, toScalarI,
    FunCodeV(..), vectorMapR, vectorMapC, vectorMapF, vectorMapQ, vectorMapI,
    FunCodeSV(..), vectorMapValR, vectorMapValC, vectorMapValF, vectorMapValQ, vectorMapValI,
    FunCodeVV(..), vectorZipR, vectorZipC, vectorZipF, vectorZipQ, vectorZipI,
    vectorScan, saveMatrix,
    Seed, RandDist(..), randomVector,
    sortVector, roundVector,
    range
) where

import Data.Packed.Internal.Common
import Data.Packed.Internal.Signatures
import Data.Packed.Internal.Vector
import Data.Packed.Internal.Matrix

import Data.Complex
import Foreign.Marshal.Alloc(free,malloc)
import Foreign.Marshal.Array(newArray,copyArray)
import Foreign.Ptr(Ptr)
import Foreign.Storable(peek)
import Foreign.C.Types
import Foreign.C.String
import System.IO.Unsafe(unsafePerformIO)

import Control.Monad(when)



fromei x = fromIntegral (fromEnum x) :: CInt

data FunCodeV = Sin
              | Cos
              | Tan
              | Abs
              | ASin
              | ACos
              | ATan
              | Sinh
              | Cosh
              | Tanh
              | ASinh
              | ACosh
              | ATanh
              | Exp
              | Log
              | Sign
              | Sqrt
              deriving Enum

data FunCodeSV = Scale
               | Recip
               | AddConstant
               | Negate
               | PowSV
               | PowVS
               | ModSV
               | ModVS
               deriving Enum

data FunCodeVV = Add
               | Sub
               | Mul
               | Div
               | Pow
               | ATan2
               | Mod
               deriving Enum

data FunCodeS = Norm2
              | AbsSum
              | MaxIdx
              | Max
              | MinIdx
              | Min
              deriving Enum

------------------------------------------------------------------

-- | sum of elements
sumF :: Vector Float -> Float
sumF = sumg c_sumF

-- | sum of elements
sumR :: Vector Double -> Double
sumR = sumg c_sumR

-- | sum of elements
sumQ :: Vector (Complex Float) -> Complex Float
sumQ = sumg c_sumQ

-- | sum of elements
sumC :: Vector (Complex Double) -> Complex Double
sumC = sumg c_sumC

-- | sum of elements
sumI :: Vector CInt -> CInt
sumI = sumg c_sumI

sumg f x = unsafePerformIO $ do
    r <- createVector 1
    app2 f vec x vec r "sum"
    return $ r @> 0

foreign import ccall unsafe "sumF" c_sumF :: TFF
foreign import ccall unsafe "sumR" c_sumR :: TVV
foreign import ccall unsafe "sumQ" c_sumQ :: TQVQV
foreign import ccall unsafe "sumC" c_sumC :: TCVCV
foreign import ccall unsafe "sumC" c_sumI :: CV CInt (CV CInt (IO CInt))

-- | product of elements
prodF :: Vector Float -> Float
prodF = prodg c_prodF

-- | product of elements
prodR :: Vector Double -> Double
prodR = prodg c_prodR

-- | product of elements
prodQ :: Vector (Complex Float) -> Complex Float
prodQ = prodg c_prodQ

-- | product of elements
prodC :: Vector (Complex Double) -> Complex Double
prodC = prodg c_prodC

-- | product of elements
prodI :: Vector CInt -> CInt
prodI = prodg c_prodI


prodg f x = unsafePerformIO $ do
    r <- createVector 1
    app2 f vec x vec r "prod"
    return $ r @> 0


foreign import ccall unsafe "prodF" c_prodF :: TFF
foreign import ccall unsafe "prodR" c_prodR :: TVV
foreign import ccall unsafe "prodQ" c_prodQ :: TQVQV
foreign import ccall unsafe "prodC" c_prodC :: TCVCV
foreign import ccall unsafe "prodI" c_prodI :: CV CInt (CV CInt (IO CInt))

------------------------------------------------------------------

toScalarAux fun code v = unsafePerformIO $ do
    r <- createVector 1
    app2 (fun (fromei code)) vec v vec r "toScalarAux"
    return (r `at` 0)

vectorMapAux fun code v = unsafePerformIO $ do
    r <- createVector (dim v)
    app2 (fun (fromei code)) vec v vec r "vectorMapAux"
    return r

vectorMapValAux fun code val v = unsafePerformIO $ do
    r <- createVector (dim v)
    pval <- newArray [val]
    app2 (fun (fromei code) pval) vec v vec r "vectorMapValAux"
    free pval
    return r

vectorZipAux fun code u v = unsafePerformIO $ do
    r <- createVector (dim u)
    app3 (fun (fromei code)) vec u vec v vec r "vectorZipAux"
    return r

---------------------------------------------------------------------

-- | obtains different functions of a vector: norm1, norm2, max, min, posmax, posmin, etc.
toScalarR :: FunCodeS -> Vector Double -> Double
toScalarR oper =  toScalarAux c_toScalarR (fromei oper)

foreign import ccall unsafe "toScalarR" c_toScalarR :: CInt -> TVV

-- | obtains different functions of a vector: norm1, norm2, max, min, posmax, posmin, etc.
toScalarF :: FunCodeS -> Vector Float -> Float
toScalarF oper =  toScalarAux c_toScalarF (fromei oper)

foreign import ccall unsafe "toScalarF" c_toScalarF :: CInt -> TFF

-- | obtains different functions of a vector: only norm1, norm2
toScalarC :: FunCodeS -> Vector (Complex Double) -> Double
toScalarC oper =  toScalarAux c_toScalarC (fromei oper)

foreign import ccall unsafe "toScalarC" c_toScalarC :: CInt -> TCVV

-- | obtains different functions of a vector: only norm1, norm2
toScalarQ :: FunCodeS -> Vector (Complex Float) -> Float
toScalarQ oper =  toScalarAux c_toScalarQ (fromei oper)

foreign import ccall unsafe "toScalarQ" c_toScalarQ :: CInt -> TQVF

-- | obtains different functions of a vector: norm1, norm2, max, min, posmax, posmin, etc.
toScalarI :: FunCodeS -> Vector CInt -> CInt
toScalarI oper =  toScalarAux c_toScalarI (fromei oper)

foreign import ccall unsafe "toScalarI" c_toScalarI :: CInt -> CV CInt (CV CInt (IO CInt))

------------------------------------------------------------------

-- | map of real vectors with given function
vectorMapR :: FunCodeV -> Vector Double -> Vector Double
vectorMapR = vectorMapAux c_vectorMapR

foreign import ccall unsafe "mapR" c_vectorMapR :: CInt -> TVV

-- | map of complex vectors with given function
vectorMapC :: FunCodeV -> Vector (Complex Double) -> Vector (Complex Double)
vectorMapC oper = vectorMapAux c_vectorMapC (fromei oper)

foreign import ccall unsafe "mapC" c_vectorMapC :: CInt -> TCVCV

-- | map of real vectors with given function
vectorMapF :: FunCodeV -> Vector Float -> Vector Float
vectorMapF = vectorMapAux c_vectorMapF

foreign import ccall unsafe "mapF" c_vectorMapF :: CInt -> TFF

-- | map of real vectors with given function
vectorMapQ :: FunCodeV -> Vector (Complex Float) -> Vector (Complex Float)
vectorMapQ = vectorMapAux c_vectorMapQ

foreign import ccall unsafe "mapQ" c_vectorMapQ :: CInt -> TQVQV

-- | map of real vectors with given function
vectorMapI :: FunCodeV -> Vector CInt -> Vector CInt
vectorMapI = vectorMapAux c_vectorMapI

foreign import ccall unsafe "mapI" c_vectorMapI :: CInt -> CV CInt (CV CInt (IO CInt))

-------------------------------------------------------------------

-- | map of real vectors with given function
vectorMapValR :: FunCodeSV -> Double -> Vector Double -> Vector Double
vectorMapValR oper = vectorMapValAux c_vectorMapValR (fromei oper)

foreign import ccall unsafe "mapValR" c_vectorMapValR :: CInt -> Ptr Double -> TVV

-- | map of complex vectors with given function
vectorMapValC :: FunCodeSV -> Complex Double -> Vector (Complex Double) -> Vector (Complex Double)
vectorMapValC = vectorMapValAux c_vectorMapValC

foreign import ccall unsafe "mapValC" c_vectorMapValC :: CInt -> Ptr (Complex Double) -> TCVCV

-- | map of real vectors with given function
vectorMapValF :: FunCodeSV -> Float -> Vector Float -> Vector Float
vectorMapValF oper = vectorMapValAux c_vectorMapValF (fromei oper)

foreign import ccall unsafe "mapValF" c_vectorMapValF :: CInt -> Ptr Float -> TFF

-- | map of complex vectors with given function
vectorMapValQ :: FunCodeSV -> Complex Float -> Vector (Complex Float) -> Vector (Complex Float)
vectorMapValQ oper = vectorMapValAux c_vectorMapValQ (fromei oper)

foreign import ccall unsafe "mapValQ" c_vectorMapValQ :: CInt -> Ptr (Complex Float) -> TQVQV

-- | map of real vectors with given function
vectorMapValI :: FunCodeSV -> CInt -> Vector CInt -> Vector CInt
vectorMapValI oper = vectorMapValAux c_vectorMapValI (fromei oper)

foreign import ccall unsafe "mapValI" c_vectorMapValI :: CInt -> Ptr CInt -> CV CInt (CV CInt (IO CInt))


-------------------------------------------------------------------

-- | elementwise operation on real vectors
vectorZipR :: FunCodeVV -> Vector Double -> Vector Double -> Vector Double
vectorZipR = vectorZipAux c_vectorZipR

foreign import ccall unsafe "zipR" c_vectorZipR :: CInt -> TVVV

-- | elementwise operation on complex vectors
vectorZipC :: FunCodeVV -> Vector (Complex Double) -> Vector (Complex Double) -> Vector (Complex Double)
vectorZipC = vectorZipAux c_vectorZipC

foreign import ccall unsafe "zipC" c_vectorZipC :: CInt -> TCVCVCV

-- | elementwise operation on real vectors
vectorZipF :: FunCodeVV -> Vector Float -> Vector Float -> Vector Float
vectorZipF = vectorZipAux c_vectorZipF

foreign import ccall unsafe "zipF" c_vectorZipF :: CInt -> TFFF

-- | elementwise operation on complex vectors
vectorZipQ :: FunCodeVV -> Vector (Complex Float) -> Vector (Complex Float) -> Vector (Complex Float)
vectorZipQ = vectorZipAux c_vectorZipQ

foreign import ccall unsafe "zipQ" c_vectorZipQ :: CInt -> TQVQVQV

-- | elementwise operation on CInt vectors
vectorZipI :: FunCodeVV -> Vector CInt -> Vector CInt -> Vector CInt
vectorZipI = vectorZipAux c_vectorZipI

foreign import ccall unsafe "zipI" c_vectorZipI :: CInt -> CV CInt (CV CInt (CV CInt (IO CInt)))


--------------------------------------------------------------------------------

foreign import ccall unsafe "vectorScan" c_vectorScan
    :: CString -> Ptr CInt -> Ptr (Ptr Double) -> IO CInt

vectorScan :: FilePath -> IO (Vector Double)
vectorScan s = do
    pp <- malloc
    pn <- malloc
    cs <- newCString s
    ok <- c_vectorScan cs pn pp
    when (not (ok == 0)) $
        error ("vectorScan: file \"" ++ s ++"\" not found")
    n <- fromIntegral <$> peek pn
    p <- peek pp
    v <- createVector n
    free pn
    free cs
    unsafeWith v $ \pv -> copyArray pv p n
    free p
    free pp
    return v

--------------------------------------------------------------------------------

foreign import ccall unsafe "saveMatrix" c_saveMatrix
    :: CString -> CString -> TM

{- | save a matrix as a 2D ASCII table
-}
saveMatrix
    :: FilePath
    -> String        -- ^ \"printf\" format (e.g. \"%.2f\", \"%g\", etc.)
    -> Matrix Double
    -> IO ()
saveMatrix name format m = do
    cname   <- newCString name
    cformat <- newCString format
    app1 (c_saveMatrix cname cformat) mat m "saveMatrix"
    free cname
    free cformat
    return ()

--------------------------------------------------------------------------------

type Seed = Int

data RandDist = Uniform  -- ^ uniform distribution in [0,1)
              | Gaussian -- ^ normal distribution with mean zero and standard deviation one
              deriving Enum

-- | Obtains a vector of pseudorandom elements (use randomIO to get a random seed).
randomVector :: Seed
             -> RandDist -- ^ distribution
             -> Int      -- ^ vector size
             -> Vector Double
randomVector seed dist n = unsafePerformIO $ do
    r <- createVector n
    app1 (c_random_vector (fi seed) ((fi.fromEnum) dist)) vec r "randomVector"
    return r

foreign import ccall unsafe "random_vector" c_random_vector :: CInt -> CInt -> TV

--------------------------------------------------------------------------------

sortVector v = unsafePerformIO $ do
    r <- createVector (dim v)
    app2 c_sort_values vec v vec r "sortVector"
    return r

foreign import ccall unsafe "sort_values" c_sort_values :: TVV

--------------------------------------------------------------------------------

roundVector v = unsafePerformIO $ do
    r <- createVector (dim v)
    app2 c_round_vector vec v vec r "roundVector"
    return r

foreign import ccall unsafe "round_vector" c_round_vector :: TVV

--------------------------------------------------------------------------------

range :: Int -> Idxs
range n = unsafePerformIO $ do
    r <- createVector n
    app1 c_range_vector vec r "range"
    return r

foreign import ccall unsafe "range_vector" c_range_vector :: CV CInt (IO CInt)

