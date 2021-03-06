{- LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE RebindableSyntax #-}
{- LANGUAGE ImplicitPrelude #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{- LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeSynonymInstances #-}

{-# OPTIONS_GHC -Wno-missing-fields #-}
{- OPTIONS_GHC -F -pgmFderive -optF-F #-}

module Fsm where

import Control.Monad.State
import Data.Set as S
import Foreign
import Foreign.C.String hiding (CString)
import Foreign.C.Types
import Foreign.Marshal.Alloc
import Foreign.Ptr
import Foreign.Storable
import Prelude
import Test.QuickCheck hiding (Success)
import Test.QuickCheck.Arbitrary
import Test.QuickCheck.Gen
import Test.QuickCheck.Monadic

import CogentMonad hiding (return, (>>=), (>>))
import qualified CogentMonad as CogentMonad
import Corres
import qualified FFI as FFI
import Fsm_Shallow_Desugar 
-- import WordArray
import Util


run_cogent_fsm_init = do
  mnt_st <- generate gen_MountState
  fsm_st <- generate gen_FsmState
  cogent_fsm_init mnt_st fsm_st



hs_fsm_init_nd :: MountState -> FsmState -> Cogent_monad (Either ErrCode FsmState)
hs_fsm_init_nd mount_st fsm_st = do
  let nb_eb' = nb_eb (super mount_st)
  ((return $ Left eNoMem) `alternative` (return $ Right $ replicate (fromIntegral nb_eb') 0)) >>= \case
    Left e -> return $ Left e
    Right used_eb -> 
      ((return $ Left eNoMem) `alternative` (return $ Right $ replicate (fromIntegral nb_eb') 0)) >>= \case
        Left e -> return $ Left e
        Right dirty_space ->
          let nb_free_eb = nb_eb' - bilbyFsFirstLogEbNum in
          (return $ Left eNoMem) `alternative` (return $ Right $ fsm_st { used_eb, dirty_space, nb_free_eb })
  where (>>=)  = (CogentMonad.>>=)
        return = (CogentMonad.return)
        (>>)   = (CogentMonad.>>)

hs_fsm_init :: MountState -> FsmState -> State [Bool] (Either ErrCode FsmState)
hs_fsm_init mount_st fsm_st = do
  let nb_eb' = nb_eb (super mount_st)
  d <- pop
  if | not d -> return $ Left eNoMem
     | otherwise -> do
       let used_eb = replicate (fromIntegral nb_eb') 0
       d <- pop
       if | not d -> return $ Left eNoMem
          | otherwise -> do
            let dirty_space = replicate (fromIntegral nb_eb') 0
                nb_free_eb = nb_eb' - bilbyFsFirstLogEbNum
            return $ Right $ fsm_st { used_eb, dirty_space, nb_free_eb }
  where
    pop :: State [a] a
    pop = get >>= \(d:ds) -> put ds >> return d 

cogent_fsm_init :: MountState -> FsmState -> IO (Either ErrCode FsmState, [Bool])
cogent_fsm_init mount_st fsm_st = do
  p_arg <- new =<< mk_fsm_init_arg mount_st fsm_st
  p_ret <- c_fsm_init p_arg
  -- putStrLn $ "p_ret = " ++ show p_ret
  rets <- peek p_ret
  -- putStrLn $ "ret = " ++ show ret
  mk_fsm_init_ret rets

foreign import ccall unsafe "fsm_wrapper_pp_inferred.c ffi_fsm_init"
  c_fsm_init :: Ptr FFI.Ct21 -> IO (Ptr FFI.Cffi_fsm_init_ds)

release_fsm_init :: Either ErrCode FsmState -> IO ()
release_fsm_init (Left _) = return ()
release_fsm_init (Right r) = conv_FsmState r >>= new >>= c_destroy_Ct20

foreign import ccall unsafe "fsm_wrapper_pp_inferred.c ffi_destroy_Ct20"
  c_destroy_Ct20 :: Ptr FFI.Ct20 -> IO ()



{-------------------------------------------------------------------------------

+-------------------------+
| abstract Isabelle specs |
+-------------------------+
          ^
          | refines (proof)
          |
+-------------------------+    generates    +----------------------------+
|   Isabelle embedding    |<~~~~~~~~~~~~~~~~| non-det version of Hs spec |<------+
+-------------------------+                 +----------------------------+       |
                                                         ^                       |
                                                         | refines (qc)          |
                                                         |                       |
                                        +-----------------------------------+    |
                                        | det version of Hs executable spec |<---+ generates with hints
                                        +-----------------------------------+    |
                                                         ^                       /
                                                         | refines (qc)         /
                                                         |                     /
+-------------------------+       generates    +-------------------+          /
| Cogent/C implementation | ~~~~~~~~~~~~~~~~~~>| Haskell embedding | (QC arbitrary gen here)
+-------------------------+                    +-------------------+          |
            ^                                                                 |
            |                        generates                                |
            \-----------------------------------------------------------------/


-------------------------------------------------------------------------------}



gen_MountState :: Gen MountState
gen_MountState = arbitrary

gen_FsmState :: Gen FsmState
gen_FsmState = arbitrary

-- the following two functions are for performance testing
prop_hs_fsm_init = monadicIO $ forAllM gen_MountState $ \mount_st ->
                               forAllM gen_FsmState   $ \fsm_st   -> run $ do
                                 ra <- return $ hs_fsm_init_nd mount_st fsm_st
                                 return $ ra `seq` True

prop_cogent_fsm_init = monadicIO $ forAllM gen_MountState $ \mount_st ->
                                   forAllM gen_FsmState   $ \fsm_st   -> run $ do
                                     (rc,_) <- cogent_fsm_init mount_st fsm_st
                                     release_fsm_init rc
                                     return True

{- This is an instance of the core corres theorem -}
prop_fsm_init_corres = monadicIO $ forAllM gen_MountState $ \mount_st ->
                                   forAllM gen_FsmState   $ \fsm_st   -> run $ do
                                     (rc,_) <- cogent_fsm_init mount_st fsm_st
                                     ra <- return $ hs_fsm_init_nd mount_st fsm_st
                                     r  <- return $ corres fsm_init_ret_rel ra rc
                                     release_fsm_init rc
                                     return r

fsm_init_ret_rel :: Either ErrCode FsmState -> Either ErrCode FsmState -> Bool
fsm_init_ret_rel (Left l1) (Left l2) = l1 == l2
fsm_init_ret_rel (Right (R27 f1 f2 f3 f4)) (Right (R27 f1' f2' f3' f4')) = f1 == f1' && f2 == f2' && f3 == f3'
fsm_init_ret_rel _ _ = False


prop_fsm_init_corres' = monadicIO $ forAllM gen_MountState $ \mount_st ->
                                    forAllM gen_FsmState   $ \fsm_st   -> run $ do
                                      (ra,ds) <- cogent_fsm_init mount_st fsm_st
                                      rc <- return $ evalState (hs_fsm_init mount_st fsm_st) ds
                                      r  <- return $ corres' fsm_init_ret_rel ra rc
                                      release_fsm_init ra
                                      return r

prop_fsm_init_det_corres_det = forAll gen_MountState $ \mount_st -> 
                               forAll gen_FsmState   $ \fsm_st   -> 
                               forAll (vectorOf 2 (arbitrary :: Gen Bool)) $ \ds -> do
                                 let rnd = hs_fsm_init_nd mount_st fsm_st
                                     rd  = evalState (hs_fsm_init mount_st fsm_st) ds
                                  in corres fsm_init_ret_rel rnd rd

{- Some trivial properties on top of the non-det Hs spec -}
prop_fsm_init_nb_free_eb = forAll gen_MountState $ \mount_st ->
                           forAll gen_FsmState   $ \fsm_st   -> 
                             nb_eb (super mount_st) >= bilbyFsFirstLogEbNum ==>
                             let rs = hs_fsm_init_nd mount_st fsm_st
                              in all (\r -> case r of
                                              Left _  -> True
                                              Right s -> nb_free_eb s <= nb_eb (super mount_st)) rs

-- ////////////////////////////////////////////////////////////////////////////
-- data conversion functions

conv_ObjSuper :: ObjSuper -> IO FFI.Ct9
conv_ObjSuper (R26 {..}) = 
  return $ FFI.Ct9 { FFI.nb_eb           = fromIntegral nb_eb
                   , FFI.eb_size         = fromIntegral eb_size
                   , FFI.io_size         = fromIntegral io_size
                   , FFI.nb_reserved_gc  = fromIntegral nb_reserved_gc
                   , FFI.nb_reserved_del = fromIntegral nb_reserved_del
                   , FFI.cur_eb          = fromIntegral cur_eb
                   , FFI.cur_offs        = fromIntegral cur_offs
                   , FFI.last_inum       = fromIntegral last_inum
                   , FFI.next_sqnum      = fromIntegral next_sqnum
                   }

conv_ObjData :: ObjData -> IO FFI.Ct10
conv_ObjData (R21 {..}) = do
  p_odata <- new =<< conv_WordArray (return . fromIntegral) odata
  return $ FFI.Ct10 (fromIntegral id) p_odata

conv_ObjDel :: ObjDel -> IO FFI.Ct11
conv_ObjDel (R19 x) = return $ FFI.Ct11 $ fromIntegral x

conv_ObjDentry :: ObjDentry -> IO FFI.Ct12
conv_ObjDentry (R24 {..}) = do
  p_name <- new =<< conv_WordArray (return . fromIntegral) name
  return $ FFI.Ct12 { FFI.ino   = fromIntegral ino
                    , FFI.dtype = fromIntegral dtype
                    , FFI.nlen  = fromIntegral nlen
                    , FFI.name  = p_name
                    }

conv_Array :: (Storable t') => (t -> IO t') -> Array t -> IO (FFI.CArray t')
conv_Array f xs = do
  p_values   <- newArray =<< mapM f xs
  p_p_values <- new p_values
  return $ FFI.CArray (CInt $ fromIntegral $ length xs) p_p_values

conv_ObjDentarr :: ObjDentarr -> IO FFI.Ct13
conv_ObjDentarr (R20 {..}) = do
  p_entries <- new =<< conv_Array conv_ObjDentry entries
  return $ FFI.Ct13 { id = fromIntegral id
                    , nb_dentry = fromIntegral nb_dentry
                    , entries = p_entries
                    }

conv_ObjInode :: ObjInode -> IO FFI.Ct14
conv_ObjInode (R22 {..}) = 
  return $ FFI.Ct14 { FFI.id        = fromIntegral id
                    , FFI.size      = fromIntegral size
                    , FFI.atime_sec = fromIntegral atime_sec
                    , FFI.ctime_sec = fromIntegral ctime_sec
                    , FFI.mtime_sec = fromIntegral mtime_sec
                    , FFI.nlink     = fromIntegral nlink
                    , FFI.uid       = fromIntegral uid
                    , FFI.gid       = fromIntegral gid
                    , FFI.mode      = fromIntegral mode
                    , FFI.flags     = fromIntegral flags
                    }

conv_WordArray :: (Storable t') => (t -> IO t') -> WordArray t -> IO (FFI.CWordArray t')
conv_WordArray f xs = FFI.CWordArray (fromIntegral $ length xs) <$> (newArray =<< mapM f xs)

conv_ObjSumEntry :: ObjSumEntry -> IO (FFI.Ct15)
conv_ObjSumEntry (R23 {..}) = 
  return $ FFI.Ct15 { FFI.id    = fromIntegral id
                    , FFI.sqnum = fromIntegral sqnum
                    , FFI.len   = fromIntegral len
                    , FFI.del_flags_and_offs = fromIntegral del_flags_and_offs
                    , FFI.count = fromIntegral count
                    }

conv_ObjSummary :: ObjSummary -> IO FFI.Ct16
conv_ObjSummary (R28 {..}) = do
  p_entries <- new =<< conv_WordArray conv_ObjSumEntry entries
  return $ FFI.Ct16 { FFI.nb_sum_entry = fromIntegral nb_sum_entry
                    , FFI.entries      = p_entries
                    , FFI.sum_offs     = fromIntegral sum_offs
                    }

conv_ObjUnion :: ObjUnion -> IO FFI.Ct17
conv_ObjUnion ounion = do
  let def_data    = FFI.Ct10 {id = 0, odata = nullPtr}
      def_del     = FFI.Ct11 {id = 0}
      def_dentarr = nullPtr
      def_inode   = nullPtr
      def_pad     = const_unit
      def_summary = nullPtr
      def_super   = nullPtr
      o = FFI.Ct17 undefined def_data def_del def_dentarr def_inode def_pad def_summary def_super
  case ounion of
    TObjData    t -> conv_ObjData    t         >>= \x -> return $ o { FFI.tag = Ctag_t $ fromIntegral $ fromEnum FFI.tag_ENUM_TObjData   , FFI.tObjData    = x }
    TObjDel     t -> conv_ObjDel     t         >>= \x -> return $ o { FFI.tag = Ctag_t $ fromIntegral $ fromEnum FFI.tag_ENUM_TObjDel    , FFI.tObjDel     = x }
    TObjDentarr t -> conv_ObjDentarr t >>= new >>= \x -> return $ o { FFI.tag = Ctag_t $ fromIntegral $ fromEnum FFI.tag_ENUM_TObjDentarr, FFI.tObjDentarr = x }
    TObjInode   t -> conv_ObjInode   t >>= new >>= \x -> return $ o { FFI.tag = Ctag_t $ fromIntegral $ fromEnum FFI.tag_ENUM_TObjInode  , FFI.tObjInode   = x }
    TObjPad     t ->                                     return $ o { FFI.tag = Ctag_t $ fromIntegral $ fromEnum FFI.tag_ENUM_TObjPad    , FFI.tObjPad     = const_unit }
    TObjSummary t -> conv_ObjSummary t >>= new >>= \x -> return $ o { FFI.tag = Ctag_t $ fromIntegral $ fromEnum FFI.tag_ENUM_TObjSummary, FFI.tObjSummary = x }
    TObjSuper   t -> conv_ObjSuper   t >>= new >>= \x -> return $ o { FFI.tag = Ctag_t $ fromIntegral $ fromEnum FFI.tag_ENUM_TObjSuper  , FFI.tObjSuper   = x }

conv_Obj :: Obj -> IO FFI.Ct18
conv_Obj (R25 {..}) = do
  ounion' <- conv_ObjUnion ounion
  return $ FFI.Ct18 { FFI.magic  = fromIntegral magic
                    , FFI.crc    = fromIntegral crc
                    , FFI.sqnum  = fromIntegral sqnum
                    , FFI.offs   = fromIntegral offs
                    , FFI.trans  = fromIntegral trans
                    , FFI.otype  = fromIntegral otype
                    , FFI.ounion = ounion'
                    }

conv_UbiVolInfo :: UbiVolInfo -> IO FFI.CUbiVolInfo
conv_UbiVolInfo = return

conv_UbiDevInfo :: UbiDevInfo -> IO FFI.CUbiDevInfo
conv_UbiDevInfo = return

conv_MountState :: MountState -> IO FFI.Ct19
conv_MountState (R11 {..}) = do
  p_super   <- new =<< conv_ObjSuper super
  p_obj_sup <- new =<< conv_Obj obj_sup
  p_vol     <- new =<< conv_UbiVolInfo vol
  p_dev     <- new =<< conv_UbiDevInfo dev
  return $ FFI.Ct19 { eb_recovery      = fromIntegral eb_recovery
                    , eb_recovery_offs = fromIntegral eb_recovery_offs
                    , super            = p_super
                    , obj_sup          = p_obj_sup
                    , super_offs       = fromIntegral super_offs
                    , vol              = p_vol
                    , dev              = p_dev
                    , no_summary       = Cbool_t $ CUChar $ fromIntegral $ fromEnum no_summary
                    }

conv_GimNode :: GimNode -> IO FFI.Ct3
conv_GimNode (R10 {..}) = return $ FFI.Ct3 (fromIntegral count) (fromIntegral sqnum)

-- Rbt is not refined
conv_Rbt :: (Storable k', Storable v') => (k -> IO k') -> (v -> IO v') -> Rbt k v -> IO (FFI.CRbt k' v')
conv_Rbt fk fv t = ttraverse fk =<< traverse fv t

conv_FsmState :: FsmState -> IO FFI.Ct20
conv_FsmState (R27 {..}) = do
  p_used_eb     <- new =<< conv_WordArray (return . fromIntegral) used_eb
  p_dirty_space <- new =<< conv_WordArray (return . fromIntegral) dirty_space
  p_gim         <- new =<< conv_Rbt (return . fromIntegral) conv_GimNode gim
  return $ FFI.Ct20 { nb_free_eb  = fromIntegral nb_free_eb
                    , used_eb     = p_used_eb
                    , dirty_space = p_dirty_space
                    , gim         = p_gim
                    }

mk_fsm_init_arg :: MountState -> FsmState -> IO FFI.Ct21
mk_fsm_init_arg mount_st fsm_st = do
  p_sys_st   <- pDummyCSysState
  p_mount_st <- new =<< conv_MountState mount_st
  p_fsm_st   <- new =<< conv_FsmState fsm_st
  return $ FFI.Ct21 { p1 = p_sys_st, p2 = p_mount_st, p3 = p_fsm_st }

conv_Ct22 :: FFI.Ct22 -> IO ErrCode
conv_Ct22 (FFI.Ct22 {..}) = return $ fromIntegral p1

conv_CWordArray :: (Storable t) => (t -> IO t') -> FFI.CWordArray t -> IO (WordArray t')
conv_CWordArray f (FFI.CWordArray {..}) = mapM f =<< peekArray (fromIntegral len) values

conv_Ct3 :: FFI.Ct3 -> IO GimNode
conv_Ct3 (FFI.Ct3 {..}) = return $ R10 (fromIntegral count) (fromIntegral sqnum)

conv_CRbt :: (Storable k, Storable v) => (k -> IO k') -> (v -> IO v') -> FFI.CRbt k v -> IO (Rbt k' v')
conv_CRbt fk fv t = ttraverse fk =<< traverse fv t

conv_Ct20 :: FFI.Ct20 -> IO FsmState
conv_Ct20 (FFI.Ct20 {..}) = do
  p_used_eb     <- peek used_eb     >>= conv_CWordArray (return . fromIntegral)
  p_dirty_space <- peek dirty_space >>= conv_CWordArray (return . fromIntegral)
  p_gim         <- peek gim         >>= conv_CRbt (return . fromIntegral) conv_Ct3
  return $ R27 (fromIntegral nb_free_eb) p_used_eb p_dirty_space p_gim

conv_Ct23 :: FFI.Ct23 -> IO (Either ErrCode FsmState)
conv_Ct23 (FFI.Ct23 {..}) = do
  let Ctag_t t = tag
  if | fromIntegral t == fromEnum FFI.tag_ENUM_Error   -> conv_Ct22 error >>= return . Left
     | fromIntegral t == fromEnum FFI.tag_ENUM_Success -> (conv_Ct20 =<< peek success) >>= return . Right
     | otherwise -> Prelude.error $ "Tag is " ++ show (fromIntegral t)

conv_Ct24 :: FFI.Ct24 -> IO (Either ErrCode FsmState)
conv_Ct24 (FFI.Ct24 {..}) = conv_Ct23 p2

mk_fsm_init_ret :: FFI.Cffi_fsm_init_ds -> IO (Either ErrCode FsmState, [Bool])
mk_fsm_init_ret (FFI.Cffi_fsm_init_ds p_ret p_ds) = do
  ret <- peek p_ret
  ret' <- conv_Ct24 ret
  ds'  <- peekArray 2 p_ds
  return $ (ret', ds')


-- ////////////////////////////////////////////////////////////////////////////
-- main function

return []
main = $quickCheckAll

