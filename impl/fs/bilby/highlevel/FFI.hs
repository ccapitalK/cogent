
{- LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE StandaloneDeriving #-}

module FFI where

import Foreign
import Foreign.Ptr
import Foreign.C.String
import Foreign.C.Types

tag_ENUM_Break       = Tag 0
tag_ENUM_Error       = Tag 1
tag_ENUM_Iterate     = Tag 2
tag_ENUM_None        = Tag 3
tag_ENUM_Some        = Tag 4
tag_ENUM_Success     = Tag 5
tag_ENUM_TObjData    = Tag 6
tag_ENUM_TObjDel     = Tag 7
tag_ENUM_TObjDentarr = Tag 8
tag_ENUM_TObjInode   = Tag 9
tag_ENUM_TObjPad     = Tag 10
tag_ENUM_TObjSummary = Tag 11
tag_ENUM_TObjSuper   = Tag 12

newtype CSysState = CSysState { dummy :: CChar } deriving Storable

dummyCSysState :: CSysState
dummyCSysState = CSysState $ CChar 0

pDummyCSysState :: IO (Ptr CSysState)
pDummyCSysState = new dummyCSysState

newtype Tag = Tag Int deriving (Enum)

newtype Ctag_t = Ctag_t CInt deriving Storable
newtype Cunit_t = Cunit_t { dummy :: CInt } deriving Storable
newtype Cbool_t = Cbool_t { boolean :: CUChar } deriving Storable

const_unit = Cunit_t $ CInt 0
const_true  = Cbool_t $ CUChar 1
const_false = Cbool_t $ CUChar 0

type Cu8  = CUChar
type Cu16 = CUShort 
type Cu32 = CUInt
type Cu64 = CULLong

data Ct435 = Ct435 { p1 :: Ptr CSysState, p2 :: Ct434 }

instance Storable Ct435 where
  sizeOf    _ = 40
  alignment _ = 8
  peek ptr = Ct435 <$> (\p -> peekByteOff p 0) ptr <*> (\p -> peekByteOff p 8) ptr
  poke ptr (Ct435 f1 f2) = (\p -> pokeByteOff p 0) ptr f1 >> (\p -> pokeByteOff p 8) ptr f2

data Ct434 = Ct434 {
    tag     :: Ctag_t
  , error   :: Ct433
  , success :: Ptr Ct68
}

instance Storable Ct434 where
  sizeOf    _ = 32
  alignment _ = 8
  peek ptr = Ct434 <$> (\p -> peekByteOff p 0 ) ptr
                   <*> (\p -> peekByteOff p 8 ) ptr
                   <*> (\p -> peekByteOff p 24) ptr
  poke ptr (Ct434 f1 f2 f3) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 8 ) ptr f2
    (\p -> pokeByteOff p 24) ptr f3

data Ct433 = Ct433 { p1 :: Cu32, p2 :: Ptr Ct68 }

instance Storable Ct433 where
  sizeOf    _ = 16
  alignment _ = 8
  peek ptr = Ct433 <$> (\p -> peekByteOff p 0) ptr <*> (\p -> peekByteOff p 8) ptr
  poke ptr (Ct433 p1 p2) = (\p -> pokeByteOff p 0) ptr p1 >> (\p -> pokeByteOff p 8) ptr p2

data Ct432 = Ct432 { p1 :: Ptr CSysState, p2 :: Ptr Ct72, p3 :: Ptr Ct68 }

instance Storable Ct432 where
  sizeOf    _ = 24
  alignment _ = 8
  peek ptr = Ct432 <$> (\p -> peekByteOff p 0 ) ptr
                   <*> (\p -> peekByteOff p 8 ) ptr
                   <*> (\p -> peekByteOff p 16) ptr
  poke ptr (Ct432 p1 p2 p3) = do
    (\p -> pokeByteOff p 0 ) ptr p1
    (\p -> pokeByteOff p 8 ) ptr p2
    (\p -> pokeByteOff p 16) ptr p3

data Ct72 = Ct72 {
    eb_recovery      :: Cu32
  , eb_recovery_offs :: Cu32
  , super            :: Ptr Ct39
  , obj_sup          :: Ptr Ct66
  , super_offs       :: Cu32
  , vol              :: Ptr CUbiVolInfo
  , dev              :: Ptr CUbiDevInfo
  , no_summary       :: Cbool_t
  }

instance Storable Ct72 where
  sizeOf    _ = 56
  alignment _ = 8
  peek ptr = Ct72 <$> (\p -> peekByteOff p 0 ) ptr
                  <*> (\p -> peekByteOff p 4 ) ptr
                  <*> (\p -> peekByteOff p 8 ) ptr
                  <*> (\p -> peekByteOff p 16) ptr
                  <*> (\p -> peekByteOff p 24) ptr
                  <*> (\p -> peekByteOff p 32) ptr
                  <*> (\p -> peekByteOff p 40) ptr
                  <*> (\p -> peekByteOff p 48) ptr
  poke ptr (Ct72 f1 f2 f3 f4 f5 f6 f7 f8) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 4 ) ptr f2
    (\p -> pokeByteOff p 8 ) ptr f3
    (\p -> pokeByteOff p 16) ptr f4
    (\p -> pokeByteOff p 24) ptr f5
    (\p -> pokeByteOff p 32) ptr f6
    (\p -> pokeByteOff p 40) ptr f7
    (\p -> pokeByteOff p 48) ptr f8

data Ct68 = Ct68 {
    nb_free_eb  :: Cu32
  , used_eb     :: Ptr CWordArray_u8
  , dirty_space :: Ptr CWordArray_u32
  , gim         :: Ptr CRbt_u64_ut18
  }

instance Storable Ct68 where
  sizeOf    _ = 32
  alignment _ = 8
  peek ptr = Ct68 <$> (\p -> peekByteOff p 0 ) ptr
                  <*> (\p -> peekByteOff p 8 ) ptr
                  <*> (\p -> peekByteOff p 16) ptr
                  <*> (\p -> peekByteOff p 24) ptr
  poke ptr (Ct68 f1 f2 f3 f4) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 8 ) ptr f2
    (\p -> pokeByteOff p 16) ptr f3
    (\p -> pokeByteOff p 24) ptr f4

data Ct66 = Ct66 {
    magic  :: Cu32
  , crc    :: Cu32
  , sqnum  :: Cu64
  , offs   :: Cu32
  , trans  :: Cu8
  , otype  :: Cu8
  , ounion :: Ct65
  }

instance Storable Ct66 where
  sizeOf    _ = 96
  alignment _ = 8
  peek ptr = Ct66 <$> (\p -> peekByteOff p 0 ) ptr
                  <*> (\p -> peekByteOff p 4 ) ptr
                  <*> (\p -> peekByteOff p 8 ) ptr
                  <*> (\p -> peekByteOff p 16) ptr
                  <*> (\p -> peekByteOff p 20) ptr
                  <*> (\p -> peekByteOff p 22) ptr
                  <*> (\p -> peekByteOff p 24) ptr
  poke ptr (Ct66 f1 f2 f3 f4 f5 f6 f7) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 4 ) ptr f2
    (\p -> pokeByteOff p 8 ) ptr f3
    (\p -> pokeByteOff p 16) ptr f4
    (\p -> pokeByteOff p 20) ptr f5
    (\p -> pokeByteOff p 22) ptr f6
    (\p -> pokeByteOff p 24) ptr f7

data Ct65 = Ct65 {
    tag         :: Ctag_t
  , tObjData    :: Ct62
  , tObjDel     :: Ct63
  , tObjDentarr :: Ptr Ct64
  , tObjInode   :: Ptr Ct45
  , tObjPad     :: Cunit_t
  , tObjSummary :: Ptr Ct42
  , tObjSuper   :: Ptr Ct39
  }

instance Storable Ct65 where
  sizeOf    _ = 72
  alignment _ = 8
  peek ptr = Ct65 <$> (\p -> peekByteOff p 0 ) ptr
                  <*> (\p -> peekByteOff p 8 ) ptr
                  <*> (\p -> peekByteOff p 24) ptr
                  <*> (\p -> peekByteOff p 32) ptr
                  <*> (\p -> peekByteOff p 40) ptr
                  <*> (\p -> peekByteOff p 48) ptr
                  <*> (\p -> peekByteOff p 56) ptr
                  <*> (\p -> peekByteOff p 64) ptr
  poke ptr (Ct65 f1 f2 f3 f4 f5 f6 f7 f8) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 8 ) ptr f2
    (\p -> pokeByteOff p 24) ptr f3
    (\p -> pokeByteOff p 32) ptr f4
    (\p -> pokeByteOff p 40) ptr f5
    (\p -> pokeByteOff p 48) ptr f6
    (\p -> pokeByteOff p 56) ptr f7
    (\p -> pokeByteOff p 64) ptr f8

data Ct64 = Ct64 {
    id        :: Cu64
  , nb_dentry :: Cu32
  , entries   :: Ptr CArray_t48
  }

instance Storable Ct64 where
  sizeOf    _ = 24
  alignment _ = 8
  peek ptr = Ct64 <$> (\p -> peekByteOff p 0 ) ptr
                  <*> (\p -> peekByteOff p 8 ) ptr
                  <*> (\p -> peekByteOff p 16) ptr
  poke ptr (Ct64 f1 f2 f3) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 8 ) ptr f2
    (\p -> pokeByteOff p 16) ptr f3


newtype Ct63 = Ct63 { id :: Cu64 } deriving (Storable)

data Ct62 = Ct62 { id :: Cu64, odata :: Ptr CWordArray_u8 }

instance Storable Ct62 where
  sizeOf    _ = 16
  alignment _ = 8
  peek ptr = Ct62 <$> (\p -> peekByteOff p 0) ptr <*> (\p -> peekByteOff p 8) ptr
  poke ptr (Ct62 id odata) = (\p -> pokeByteOff p 0) ptr id >> (\p -> pokeByteOff p 8) ptr odata

data Ct48 = Ct48 { 
    ino   :: Cu32
  , dtype :: Cu8
  , nlen  :: Cu16
  , name  :: Ptr CWordArray_u8
  }

instance Storable Ct48 where
  sizeOf    _ = 16
  alignment _ = 8
  peek ptr = Ct48 <$> (\p -> peekByteOff p 0 ) ptr
                  <*> (\p -> peekByteOff p 4 ) ptr
                  <*> (\p -> peekByteOff p 6 ) ptr
                  <*> (\p -> peekByteOff p 8 ) ptr
  poke ptr (Ct48 f1 f2 f3 f4) = do
    (\p -> pokeByteOff p 0) ptr f1
    (\p -> pokeByteOff p 4) ptr f2
    (\p -> pokeByteOff p 6) ptr f3
    (\p -> pokeByteOff p 8) ptr f4

data Ct45 = Ct45 {
    id        :: Cu64
  , size      :: Cu64
  , atime_sec :: Cu64
  , ctime_sec :: Cu64
  , mtime_sec :: Cu64
  , nlink     :: Cu32
  , uid       :: Cu32
  , gid       :: Cu32
  , mode      :: Cu32
  , flags     :: Cu32
  }

instance Storable Ct45 where
  sizeOf    _ = 64
  alignment _ = 8
  peek ptr = Ct45 <$> (\p -> peekByteOff p 0 ) ptr
                  <*> (\p -> peekByteOff p 8 ) ptr
                  <*> (\p -> peekByteOff p 16) ptr
                  <*> (\p -> peekByteOff p 24) ptr
                  <*> (\p -> peekByteOff p 32) ptr
                  <*> (\p -> peekByteOff p 40) ptr
                  <*> (\p -> peekByteOff p 44) ptr
                  <*> (\p -> peekByteOff p 48) ptr
                  <*> (\p -> peekByteOff p 52) ptr
                  <*> (\p -> peekByteOff p 56) ptr
  poke ptr (Ct45 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 8 ) ptr f2
    (\p -> pokeByteOff p 16) ptr f3
    (\p -> pokeByteOff p 24) ptr f4
    (\p -> pokeByteOff p 32) ptr f5
    (\p -> pokeByteOff p 40) ptr f6
    (\p -> pokeByteOff p 44) ptr f7
    (\p -> pokeByteOff p 48) ptr f8
    (\p -> pokeByteOff p 52) ptr f9
    (\p -> pokeByteOff p 56) ptr f10

data Ct42 = Ct42 {
    nb_sum_entry :: Cu32
  , entries      :: Ptr CWordArray_ut10
  , sum_offs     :: Cu32
  }

instance Storable Ct42 where
  sizeOf    _ = 24
  alignment _ = 8
  peek ptr = Ct42 <$> (\p -> peekByteOff p 0 ) ptr
                  <*> (\p -> peekByteOff p 8 ) ptr
                  <*> (\p -> peekByteOff p 16) ptr
  poke ptr (Ct42 f1 f2 f3) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 8 ) ptr f2
    (\p -> pokeByteOff p 16) ptr f3


data Ct39 = Ct39 {
    nb_eb           :: Cu32
  , eb_size         :: Cu32
  , io_size         :: Cu32
  , nb_reserved_gc  :: Cu32
  , nb_reserved_del :: Cu32
  , cur_eb          :: Cu32
  , cur_offs        :: Cu32
  , last_inum       :: Cu32
  , next_sqnum      :: Cu64
  }

instance Storable Ct39 where
  sizeOf    _ = 40
  alignment _ = 8
  peek ptr = Ct39 <$> (\p -> peekByteOff p 0 ) ptr
                  <*> (\p -> peekByteOff p 4 ) ptr
                  <*> (\p -> peekByteOff p 8 ) ptr
                  <*> (\p -> peekByteOff p 12) ptr
                  <*> (\p -> peekByteOff p 16) ptr
                  <*> (\p -> peekByteOff p 20) ptr
                  <*> (\p -> peekByteOff p 24) ptr
                  <*> (\p -> peekByteOff p 28) ptr
                  <*> (\p -> peekByteOff p 32) ptr
  poke ptr (Ct39 f1 f2 f3 f4 f5 f6 f7 f8 f9) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 4 ) ptr f2
    (\p -> pokeByteOff p 8 ) ptr f3
    (\p -> pokeByteOff p 12) ptr f4
    (\p -> pokeByteOff p 16) ptr f5
    (\p -> pokeByteOff p 20) ptr f6
    (\p -> pokeByteOff p 24) ptr f7
    (\p -> pokeByteOff p 28) ptr f8
    (\p -> pokeByteOff p 32) ptr f9

data Ct10 = Ct10 {
    id    :: Cu64
  , sqnum :: Cu64
  , len   :: Cu32
  , del_flags_and_offs :: Cu32
  , count :: Cu16
  }

instance Storable Ct10 where
  sizeOf    _ = 32
  alignment _ = 8
  peek ptr = Ct10 <$> (\p -> peekByteOff p 0 ) ptr
                  <*> (\p -> peekByteOff p 8 ) ptr
                  <*> (\p -> peekByteOff p 16) ptr
                  <*> (\p -> peekByteOff p 20) ptr
                  <*> (\p -> peekByteOff p 24) ptr
  poke ptr (Ct10 f1 f2 f3 f4 f5) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 8 ) ptr f2
    (\p -> pokeByteOff p 16) ptr f3 
    (\p -> pokeByteOff p 20) ptr f4
    (\p -> pokeByteOff p 24) ptr f5

type CUbiVolInfo = Cubi_volume_info

data Cubi_volume_info = Cubi_volume_info {
    ubi_num         :: CInt
  , vol_id          :: CInt
  , size            :: CInt
  , used_bytes      :: CLLong
  , used_ebs        :: CInt
  , vol_type        :: CInt
  , corrupted       :: CInt
  , upd_marker      :: CInt
  , alignment       :: CInt
  , usable_leb_size :: CInt
  , name_len        :: CInt
  , name            :: Ptr CChar
  , cdev            :: Cdev_t
  } deriving (Show)

instance Storable Cubi_volume_info where
  sizeOf    _ = 72
  alignment _ = 8
  peek ptr = Cubi_volume_info <$> (\p -> peekByteOff p 0 ) ptr
                              <*> (\p -> peekByteOff p 4 ) ptr
                              <*> (\p -> peekByteOff p 8 ) ptr
                              <*> (\p -> peekByteOff p 16) ptr
                              <*> (\p -> peekByteOff p 24) ptr
                              <*> (\p -> peekByteOff p 28) ptr
                              <*> (\p -> peekByteOff p 32) ptr
                              <*> (\p -> peekByteOff p 36) ptr
                              <*> (\p -> peekByteOff p 40) ptr
                              <*> (\p -> peekByteOff p 44) ptr
                              <*> (\p -> peekByteOff p 48) ptr
                              <*> (\p -> peekByteOff p 56) ptr
                              <*> (\p -> peekByteOff p 64) ptr
  poke ptr (Cubi_volume_info f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 4 ) ptr f2
    (\p -> pokeByteOff p 8 ) ptr f3
    (\p -> pokeByteOff p 16) ptr f4
    (\p -> pokeByteOff p 24) ptr f5
    (\p -> pokeByteOff p 28) ptr f6
    (\p -> pokeByteOff p 32) ptr f7
    (\p -> pokeByteOff p 36) ptr f8
    (\p -> pokeByteOff p 40) ptr f9
    (\p -> pokeByteOff p 44) ptr f10
    (\p -> pokeByteOff p 48) ptr f11
    (\p -> pokeByteOff p 56) ptr f12
    (\p -> pokeByteOff p 64) ptr f13

{-
struct ubi_volume_info {
	int ubi_num;
	int vol_id;
	int size;
	long long used_bytes;
	int used_ebs;
	int vol_type;
	int corrupted;
	int upd_marker;
	int alignment;
	int usable_leb_size;
	int name_len;
	const char *name;
	dev_t cdev;
};
-}

type Cdev_t = C__kernel_dev_t
type C__kernel_dev_t = C__u32
type C__u32 = Word32

type CUbiDevInfo = Cubi_device_info

data Cubi_device_info = Cubi_device_info {
    ubi_num        :: CInt
  , leb_size       :: CInt
  , leb_start      :: CInt
  , min_io_size    :: CInt
  , max_write_size :: CInt
  , ro_mode        :: CInt
  , cdev           :: Cdev_t
  } deriving (Show)

instance Storable Cubi_device_info where
  sizeOf    _ = 28
  alignment _ = 4
  peek ptr = Cubi_device_info <$> (\p -> peekByteOff p 0 ) ptr
                              <*> (\p -> peekByteOff p 4 ) ptr
                              <*> (\p -> peekByteOff p 8 ) ptr
                              <*> (\p -> peekByteOff p 12) ptr
                              <*> (\p -> peekByteOff p 16) ptr
                              <*> (\p -> peekByteOff p 20) ptr
                              <*> (\p -> peekByteOff p 24) ptr
  poke ptr (Cubi_device_info f1 f2 f3 f4 f5 f6 f7) = do
    (\p -> pokeByteOff p 0 ) ptr f1
    (\p -> pokeByteOff p 4 ) ptr f2
    (\p -> pokeByteOff p 8 ) ptr f3
    (\p -> pokeByteOff p 12) ptr f4
    (\p -> pokeByteOff p 16) ptr f5
    (\p -> pokeByteOff p 20) ptr f6
    (\p -> pokeByteOff p 24) ptr f7

{-
struct ubi_device_info {
	int ubi_num;
	int leb_size;
	int leb_start;
	int min_io_size;
	int max_write_size;
	int ro_mode;
	dev_t cdev;
};
-}

data CArray_t48 = CArray_t48 {
    len    :: CInt
  , values :: Ptr (Ptr Ct48)
  }

instance Storable CArray_t48 where
  sizeOf    _ = 16
  alignment _ = 8
  peek ptr = CArray_t48 <$> (\p -> peekByteOff p 0) ptr
                        <*> (\p -> peekByteOff p 8) ptr
  poke ptr (CArray_t48 len values) = do
    (\p -> pokeByteOff p 0) ptr len
    (\p -> pokeByteOff p 8) ptr values

data CWordArray_u8 = CWordArray_u8 {
    len    :: CInt
  , values :: Ptr Cu8
  }

instance Storable CWordArray_u8 where
  sizeOf    _ = 16
  alignment _ = 8
  peek ptr = CWordArray_u8 <$> (\p -> peekByteOff p 0) ptr
                          <*> (\p -> peekByteOff p 8) ptr
  poke ptr (CWordArray_u8 len values) = do
    (\p -> pokeByteOff p 0) ptr len
    (\p -> pokeByteOff p 8) ptr values

data CWordArray_ut10 = CWordArray_ut10 {
    len    :: CInt
  , values :: Ptr Ct10
  }

instance Storable CWordArray_ut10 where
  sizeOf    _ = 16
  alignment _ = 8
  peek ptr = CWordArray_ut10 <$> (\p -> peekByteOff p 0) ptr
                             <*> (\p -> peekByteOff p 8) ptr
  poke ptr (CWordArray_ut10 len values) = do
    (\p -> pokeByteOff p 0) ptr len
    (\p -> pokeByteOff p 8) ptr values

data CWordArray_u32 = CWordArray_u32 {
    len    :: CInt
  , values :: Ptr Cu32
  }

instance Storable CWordArray_u32 where
  sizeOf    _ = 16
  alignment _ = 8
  peek ptr = CWordArray_u32 <$> (\p -> peekByteOff p 0) ptr
                            <*> (\p -> peekByteOff p 8) ptr
  poke ptr (CWordArray_u32 len values) = do
    (\p -> pokeByteOff p 0) ptr len
    (\p -> pokeByteOff p 8) ptr values

newtype CRbt_u64_ut18 = CRbt_u64_ut18 { rbt :: Crbt_root } deriving (Storable)

newtype Crbt_root = Crbt_root { root :: Crbt_node } deriving (Storable)

data Crbt_node = Crbt_node {
    rbt_parent_color :: CULong
  , rbt_left         :: Ptr Crbt_node
  , rbt_right        :: Ptr Crbt_node
  }

instance Storable Crbt_node where
  sizeOf    _ = 24
  alignment _ = 8
  peek ptr = Crbt_node <$> (\p -> peekByteOff p 0 ) ptr
                       <*> (\p -> peekByteOff p 8 ) ptr
                       <*> (\p -> peekByteOff p 16) ptr
  poke ptr (Crbt_node rbt_parent_color rbt_left rbt_right) = do
    (\p -> pokeByteOff p 0 ) ptr rbt_parent_color
    (\p -> pokeByteOff p 8 ) ptr rbt_left
    (\p -> pokeByteOff p 16) ptr rbt_right

