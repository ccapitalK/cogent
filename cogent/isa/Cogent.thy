(*
 * Copyright 2018, Data61
 * Commonwealth Scientific and Industrial Research Organisation (CSIRO)
 * ABN 41 687 119 230.
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(DATA61_GPL)
 *)

theory Cogent
  imports Util
begin

type_synonym name = string

type_synonym index = nat

type_synonym field = nat

section {* Prim Ops  *}

datatype num_type = U8 | U16 | U32 | U64

datatype prim_type = Num num_type | Bool | String

datatype prim_op
  = Plus num_type
  | Minus num_type
  | Times num_type
  | Divide num_type
  | Mod num_type
  | Not | And | Or
  | Gt num_type
  | Lt num_type
  | Le num_type
  | Ge num_type
  | Eq prim_type
  | NEq prim_type
  | BitAnd num_type
  | BitOr num_type
  | BitXor num_type
  | LShift num_type
  | RShift num_type
  | Complement num_type


section {* Types *}

datatype ptr_layout = PtrBits int int
                    | PtrVariant int int "(name \<times> int \<times> ptr_layout) list"
                    | PtrRecord "(name \<times> ptr_layout) list"

datatype access_perm = ReadOnly | Writable

(* Sigils represent where the memory that makes up the datatype is, and it's access permissions.
 *
 * Data is either boxed (on the heap), or unboxed (on the stack). If data is on the heap, we keep
 * track of how it is represented, and what access permissions it requires.
 *)
datatype sigil = Boxed access_perm ptr_layout
               | Unboxed

lemma sigil_cases:
  obtains (SBoxRo) r where "x = Boxed ReadOnly r"
  | (SBoxWr) r where "x = Boxed Writable r"
  | (SUnbox) "x = Unboxed"
proof (cases x)
  case (Boxed p r)
  moreover assume "(\<And>r. x = Boxed ReadOnly r \<Longrightarrow> thesis)"
    and "(\<And>r. x = Boxed Writable r \<Longrightarrow> thesis)"
  ultimately show ?thesis
    by (cases p, simp+)
qed simp

primrec sigil_perm :: "sigil \<Rightarrow> access_perm option" where
  "sigil_perm (Boxed p _) = Some p"
| "sigil_perm Unboxed     = None"

datatype type = TVar index
              | TVarBang index
              | TCon name "type list" sigil
              | TFun type type
              | TPrim prim_type
              | TSum "(name \<times> (type \<times> bool)) list"
              | TProduct type type
              | TRecord "(name \<times> type \<times> bool) list" sigil
              | TUnit

datatype lit = LBool bool
             | LU8 "8 word"
             | LU16 "16 word"
             | LU32 "32 word"
             | LU64 "64 word"
             (* etc *)

fun cast_to :: "num_type \<Rightarrow> lit \<Rightarrow> lit option" where
  "cast_to U8  (LU8  x) = Some (LU8 x)"
| "cast_to U16 (LU8  x) = Some (LU16 (ucast x))"
| "cast_to U16 (LU16 x) = Some (LU16 x)"
| "cast_to U32 (LU8  x) = Some (LU32 (ucast x))"
| "cast_to U32 (LU16 x) = Some (LU32 (ucast x))"
| "cast_to U32 (LU32 x) = Some (LU32 x)"
| "cast_to U64 (LU8  x) = Some (LU64 (ucast x))"
| "cast_to U64 (LU16 x) = Some (LU64 (ucast x))"
| "cast_to U64 (LU32 x) = Some (LU64 (ucast x))"
| "cast_to U64 (LU64 x) = Some (LU64 x)"

section {* Expressions *}

datatype 'f expr = Var index
                 | AFun 'f  "type list"
                 | Fun "'f expr" "type list"
                 | Prim prim_op "'f expr list"
                 | App "'f expr" "'f expr"
                 | Con "(name \<times> type \<times> bool) list" name "'f expr"
                 | Struct "type list" "'f expr list"
                 | Member "'f expr" field
                 | Unit
                 | Lit lit
                 | Cast num_type "'f expr"
                 | Tuple "'f expr" "'f expr"
                 | Put "'f expr" field "'f expr"
                 | Let "'f expr" "'f expr"
                 | LetBang "index set" "'f expr" "'f expr"
                 | Case "'f expr" name "'f expr" "'f expr"
                 | Esac "'f expr"
                 | If "'f expr" "'f expr" "'f expr"
                 | Take "'f expr" field "'f expr"
                 | Split "'f expr" "'f expr"

section {* Kinds *}

datatype kind_comp = D | S | E

type_synonym kind = "kind_comp set"

type_synonym poly_type = "kind list \<times> type \<times> type"

type_synonym 'v env  = "'v list"

type_synonym 'a substitution = "'a list"

fun sigil_kind :: "sigil \<Rightarrow> kind" where
  "sigil_kind (Boxed ReadOnly _) = {D,S}"
| "sigil_kind (Boxed Writable _) = {E}"
| "sigil_kind Unboxed            = {D,S,E}"

inductive kinding        :: "kind env \<Rightarrow> type               \<Rightarrow> kind \<Rightarrow> bool" ("_ \<turnstile> _ :\<kappa> _" [30,0,20] 60)
      and kinding_all    :: "kind env \<Rightarrow> type list          \<Rightarrow> kind \<Rightarrow> bool" ("_ \<turnstile>* _ :\<kappa> _" [30,0,20] 60)
      and kinding_record :: "kind env \<Rightarrow> (name \<times> type \<times> bool) list \<Rightarrow> kind \<Rightarrow> bool" ("_ \<turnstile>* _ :\<kappa>r _" [30,0,20] 60) where

   kind_tvar    : "\<lbrakk> k \<subseteq> (K ! i) ; i < length K \<rbrakk> \<Longrightarrow> K \<turnstile> TVar i :\<kappa> k"
|  kind_tvarb   : "\<lbrakk> k \<subseteq> {D, S} ; i < length K \<rbrakk> \<Longrightarrow> K \<turnstile> TVarBang i :\<kappa> k"
|  kind_tcon    : "\<lbrakk> K \<turnstile>* ts :\<kappa> k ; k \<subseteq> sigil_kind s \<rbrakk> \<Longrightarrow> K \<turnstile> TCon n ts s :\<kappa> k"
|  kind_tfun    : "\<lbrakk> K \<turnstile> a :\<kappa> ka ; K \<turnstile> b :\<kappa> kb \<rbrakk> \<Longrightarrow> K \<turnstile> TFun a b :\<kappa> k"
|  kind_tprim   : "K \<turnstile> TPrim p :\<kappa> k"
|  kind_tsum    : "\<lbrakk> distinct (map fst ts); K \<turnstile>* map (fst \<circ> snd) ts :\<kappa> k \<rbrakk> \<Longrightarrow> K \<turnstile> TSum ts :\<kappa> k"
|  kind_tprod   : "\<lbrakk> K \<turnstile> t :\<kappa> k; K \<turnstile> u :\<kappa> k \<rbrakk> \<Longrightarrow> K \<turnstile> TProduct t u :\<kappa> k"
|  kind_trec    : "\<lbrakk> distinct (map fst ts); K \<turnstile>* ts :\<kappa>r k; k \<subseteq> sigil_kind s \<rbrakk> \<Longrightarrow> K \<turnstile> TRecord ts s :\<kappa> k"
|  kind_tunit   : "K \<turnstile> TUnit :\<kappa> k"

|  kind_all_empty : "K \<turnstile>* [] :\<kappa> k"
|  kind_all_cons  : "\<lbrakk> K \<turnstile> x :\<kappa> k ; K \<turnstile>* xs :\<kappa> k \<rbrakk> \<Longrightarrow> K \<turnstile>* (x # xs) :\<kappa> k"

|  kind_record_empty : "K \<turnstile>* [] :\<kappa>r k"
|  kind_record_cons1 : "\<lbrakk> K \<turnstile> x :\<kappa> k  ; K \<turnstile>* xs :\<kappa>r k \<rbrakk> \<Longrightarrow> K \<turnstile>* ((name,x,False) # xs) :\<kappa>r k"
|  kind_record_cons2 : "\<lbrakk> K \<turnstile> x :\<kappa> k' ; K \<turnstile>* xs :\<kappa>r k \<rbrakk> \<Longrightarrow> K \<turnstile>* ((name,x,True)  # xs) :\<kappa>r k"

inductive_cases kind_tvarE         [elim] : "K \<turnstile> TVar i :\<kappa> k"
inductive_cases kind_tvarbE        [elim] : "K \<turnstile> TVarBang i :\<kappa> k"
inductive_cases kind_tconE         [elim] : "K \<turnstile> TCon n ts s :\<kappa> k"
inductive_cases kind_tfunE         [elim] : "K \<turnstile> TFun a b :\<kappa> k"
inductive_cases kind_tsumE         [elim] : "K \<turnstile> TSum ts :\<kappa> k"
inductive_cases kind_tprodE        [elim] : "K \<turnstile> TProduct t u :\<kappa> k"
inductive_cases kind_trecE         [elim] : "K \<turnstile> TRecord ts s :\<kappa> k"
inductive_cases kind_all_emptyE    [elim] : "K \<turnstile>* [] :\<kappa> k"
inductive_cases kind_all_consE     [elim] : "K \<turnstile>* (x # xs) :\<kappa> k"
inductive_cases kind_record_emptyE [elim] : "K \<turnstile>* [] :\<kappa>r k"
inductive_cases kind_record_consE  [elim] : "K \<turnstile>* (x # xs) :\<kappa>r k"
inductive_cases kind_record_cons1E [elim] : "K \<turnstile>* ((name,x,False) # xs) :\<kappa>r k"
inductive_cases kind_record_cons2E [elim] : "K \<turnstile>* ((name,x,True)  # xs) :\<kappa>r k"


definition type_wellformed :: "kind env \<Rightarrow> type \<Rightarrow> bool" ("_ \<turnstile> _ wellformed" [30,20] 60) where
  "K \<turnstile> \<tau> wellformed \<equiv> \<exists>k. K \<turnstile> \<tau> :\<kappa> k"

declare type_wellformed_def [simp]


definition type_wellformed_all :: "kind env \<Rightarrow> type list \<Rightarrow> bool" ("_ \<turnstile>* _ wellformed"[30,20]60) where
  "K \<turnstile>* \<tau>s wellformed \<equiv> \<exists>k. K \<turnstile>* \<tau>s :\<kappa> k"

declare type_wellformed_all_def [simp]

definition proc_ctx_wellformed :: "('f \<Rightarrow> poly_type) \<Rightarrow> bool" where
  "proc_ctx_wellformed \<Xi> = (\<forall> f. let (K, \<tau>i, \<tau>o) = \<Xi> f in K \<turnstile> TFun \<tau>i \<tau>o wellformed )"

section {* Observation and type instantiation *}

fun bang_sigil :: "sigil \<Rightarrow> sigil" where
  "bang_sigil (Boxed ReadOnly r) = Boxed ReadOnly r"
| "bang_sigil (Boxed Writable r) = Boxed ReadOnly r"
| "bang_sigil Unboxed            = Unboxed"

fun bang :: "type \<Rightarrow> type" where
  "bang (TVar i)       = TVarBang i"
| "bang (TVarBang i)   = TVarBang i"
| "bang (TCon n ts s)  = TCon n (map bang ts) (bang_sigil s)"
| "bang (TFun a b)     = TFun a b"
| "bang (TPrim p)      = TPrim p"
| "bang (TSum ps)      = TSum (map (\<lambda> (c, (t, b)). (c, (bang t, b))) ps)"
| "bang (TProduct t u) = TProduct (bang t) (bang u)"
| "bang (TRecord ts s) = TRecord (map (\<lambda>(n, t, b). (n, bang t, b)) ts) (bang_sigil s)"
| "bang (TUnit)        = TUnit"

fun instantiate :: "type substitution \<Rightarrow> type \<Rightarrow> type" where
  "instantiate \<delta> (TVar i)       = (if i < length \<delta> then \<delta> ! i else TVar i)"
| "instantiate \<delta> (TVarBang i)   = (if i < length \<delta> then bang (\<delta> ! i) else TVarBang i)"
| "instantiate \<delta> (TCon n ts s)  = TCon n (map (instantiate \<delta>) ts) s"
| "instantiate \<delta> (TFun a b)     = TFun (instantiate \<delta> a) (instantiate \<delta> b)"
| "instantiate \<delta> (TPrim p)      = TPrim p"
| "instantiate \<delta> (TSum ps)      = TSum (map (\<lambda> (c, t, b). (c, instantiate \<delta> t, b)) ps)"
| "instantiate \<delta> (TProduct t u) = TProduct (instantiate \<delta> t) (instantiate \<delta> u)"
| "instantiate \<delta> (TRecord ts s) = TRecord (map (\<lambda> (n, t, b). (n, instantiate \<delta> t, b)) ts) s"
| "instantiate \<delta> (TUnit)        = TUnit"

fun specialise :: "type substitution \<Rightarrow> 'f expr \<Rightarrow> 'f expr" where
  "specialise \<delta> (Var i)           = Var i"
| "specialise \<delta> (Fun f ts)        = Fun f (map (instantiate \<delta>) ts)"
| "specialise \<delta> (AFun f ts)       = AFun f (map (instantiate \<delta>) ts)"
| "specialise \<delta> (Prim p es)       = Prim p (map (specialise \<delta>) es)"
| "specialise \<delta> (App a b)         = App (specialise \<delta> a) (specialise \<delta> b)"
| "specialise \<delta> (Con as t e)      = Con (map (\<lambda> (c,t,b). (c, instantiate \<delta> t, b)) as) t (specialise \<delta> e)"
| "specialise \<delta> (Struct ts vs)    = Struct (map (instantiate \<delta>) ts) (map (specialise \<delta>) vs)"
| "specialise \<delta> (Member v f)      = Member (specialise \<delta> v) f"
| "specialise \<delta> (Unit)            = Unit"
| "specialise \<delta> (Cast t e)        = Cast t (specialise \<delta> e)"
| "specialise \<delta> (Lit v)           = Lit v"
| "specialise \<delta> (Tuple a b)       = Tuple (specialise \<delta> a) (specialise \<delta> b)"
| "specialise \<delta> (Put e f e')      = Put (specialise \<delta> e) f (specialise \<delta> e')"
| "specialise \<delta> (Let e e')        = Let (specialise \<delta> e) (specialise \<delta> e')"
| "specialise \<delta> (LetBang vs e e') = LetBang vs (specialise \<delta> e) (specialise \<delta> e')"
| "specialise \<delta> (Case e t a b)    = Case (specialise \<delta> e) t (specialise \<delta> a) (specialise \<delta> b)"
| "specialise \<delta> (Esac e)          = Esac (specialise \<delta> e)"
| "specialise \<delta> (If c t e)        = If (specialise \<delta> c) (specialise \<delta> t) (specialise \<delta> e)"
| "specialise \<delta> (Take e f e')     = Take (specialise \<delta> e) f (specialise \<delta> e')"
| "specialise \<delta> (Split v va)      = Split (specialise \<delta> v) (specialise \<delta> va)"


section {* Contexts *}

type_synonym ctx = "type option env"

definition empty :: "nat \<Rightarrow> ctx" where
  "empty \<equiv> (\<lambda> x. replicate x None)"

definition singleton :: "nat \<Rightarrow> index \<Rightarrow> type \<Rightarrow> ctx" where
  "singleton n i t \<equiv> (empty n)[i := Some t]"

declare singleton_def [simp]

definition instantiate_ctx :: "type substitution \<Rightarrow> ctx \<Rightarrow> ctx" where
  "instantiate_ctx \<delta> \<Gamma> \<equiv> map (map_option (instantiate \<delta>)) \<Gamma>"

inductive split_comp :: "kind env \<Rightarrow> type option \<Rightarrow> type option \<Rightarrow> type option \<Rightarrow> bool"
          ("_ \<turnstile> _ \<leadsto> _ \<parallel> _" [30,0,0,20] 60) where
  none  : "K \<turnstile> None \<leadsto> None \<parallel> None"
| left  : "\<lbrakk> K \<turnstile> t :\<kappa> k         \<rbrakk> \<Longrightarrow> K \<turnstile> Some t \<leadsto> Some t \<parallel> None"
| right : "\<lbrakk> K \<turnstile> t :\<kappa> k         \<rbrakk> \<Longrightarrow> K \<turnstile> Some t \<leadsto> None   \<parallel> (Some t)"
| share : "\<lbrakk> K \<turnstile> t :\<kappa> k ; S \<in> k \<rbrakk> \<Longrightarrow> K \<turnstile> Some t \<leadsto> Some t \<parallel> Some t"

definition split :: "kind env \<Rightarrow> ctx \<Rightarrow> ctx \<Rightarrow> ctx \<Rightarrow> bool" ("_ \<turnstile> _ \<leadsto> _ | _" [30,0,0,20] 60) where
  "split K \<equiv> list_all3 (split_comp K)"

lemmas split_induct[consumes 1, case_names split_empty split_cons, induct set: list_all3]
 = list_all3_induct[where P="split_comp K" for K, simplified split_def[symmetric]]

lemmas split_empty = all3Nil[where P="split_comp K" for K, simplified split_def[symmetric]]
lemmas split_cons = all3Cons[where P="split_comp K" for K, simplified split_def[symmetric]]

definition pred :: "nat \<Rightarrow> nat" where
  "pred n \<equiv> (case n of Suc n' \<Rightarrow> n')"

inductive split_bang_comp :: "kind env \<Rightarrow> bool \<Rightarrow> type option \<Rightarrow> type option \<Rightarrow> type option \<Rightarrow> bool" ("_ , _ \<turnstile> _ \<leadsto>b _ \<parallel> _") where
  none     : "K \<turnstile> x \<leadsto> a \<parallel> b \<Longrightarrow> K , False \<turnstile> x \<leadsto>b a \<parallel> b"
| dobang   : "K \<turnstile> t :\<kappa> k \<Longrightarrow> K , True \<turnstile> Some t \<leadsto>b Some (bang t) \<parallel> Some t"
(* this rule is covered by weakening, but having it here makes the proofs nicer *)
| bangdrop : "\<lbrakk> K \<turnstile> t :\<kappa> k ; D \<in> k \<rbrakk> \<Longrightarrow> K , True \<turnstile> Some t \<leadsto>b Some (bang t) \<parallel> None"

inductive split_bang :: "kind env \<Rightarrow> index set \<Rightarrow> ctx \<Rightarrow> ctx \<Rightarrow> ctx \<Rightarrow> bool"  ("_ , _ \<turnstile> _ \<leadsto>b _ | _" [30,0,0,20] 60) where
  split_bang_empty : "K , is \<turnstile> [] \<leadsto>b [] | []"
| split_bang_cons  : "\<lbrakk> is' = pred ` Set.remove (0 :: index) is
                      ; K , is'  \<turnstile> xs \<leadsto>b as | bs
                      ; K, (0 \<in> is) \<turnstile> x \<leadsto>b a \<parallel> b
                      \<rbrakk> \<Longrightarrow> K , is \<turnstile> x # xs \<leadsto>b a # as | b # bs"



inductive weakening_comp :: "kind env \<Rightarrow> type option \<Rightarrow> type option \<Rightarrow> bool" where
  none : "weakening_comp K None None"
| keep : "\<lbrakk> K \<turnstile> t :\<kappa> k \<rbrakk>         \<Longrightarrow> weakening_comp K (Some t) (Some t)"
| drop : "\<lbrakk> K \<turnstile> t :\<kappa> k ; D \<in> k \<rbrakk> \<Longrightarrow> weakening_comp K (Some t) None"

definition weakening :: "kind env \<Rightarrow> ctx \<Rightarrow> ctx \<Rightarrow> bool" ("_ \<turnstile> _ \<leadsto>w _" [30,0,20] 60) where
  "weakening K \<equiv> list_all2 (weakening_comp K)"

definition is_consumed :: "kind env \<Rightarrow> ctx \<Rightarrow> bool" ("_ \<turnstile> _ consumed" [30,20] 60 ) where
  "K \<turnstile> \<Gamma> consumed \<equiv> K \<turnstile> \<Gamma> \<leadsto>w empty (length \<Gamma>)"

declare is_consumed_def [simp]

section {* Built-in types *}

primrec prim_op_type :: "prim_op \<Rightarrow> prim_type list \<times> prim_type" where
  "prim_op_type (Plus t)   = ([Num t, Num t], Num t)"
| "prim_op_type (Times t)  = ([Num t, Num t], Num t)"
| "prim_op_type (Minus t)  = ([Num t, Num t], Num t)"
| "prim_op_type (Divide t) = ([Num t, Num t], Num t)"
| "prim_op_type (Mod t)    = ([Num t, Num t], Num t)"
| "prim_op_type (BitAnd t) = ([Num t, Num t], Num t)"
| "prim_op_type (BitOr t)  = ([Num t, Num t], Num t)"
| "prim_op_type (BitXor t) = ([Num t, Num t], Num t)"
| "prim_op_type (LShift t) = ([Num t, Num t], Num t)"
| "prim_op_type (RShift t) = ([Num t, Num t], Num t)"
| "prim_op_type (Complement t) = ([Num t], Num t)"
| "prim_op_type (Gt t)     = ([Num t, Num t], Bool )"
| "prim_op_type (Lt t)     = ([Num t, Num t], Bool )"
| "prim_op_type (Le t)     = ([Num t, Num t], Bool )"
| "prim_op_type (Ge t)     = ([Num t, Num t], Bool )"
| "prim_op_type (Eq t)     = ([t    , t    ], Bool )"
| "prim_op_type (NEq t)    = ([t    , t    ], Bool )"
| "prim_op_type (And)      = ([Bool , Bool ], Bool )"
| "prim_op_type (Or)       = ([Bool , Bool ], Bool )"
| "prim_op_type (Not)      = ([Bool],         Bool )"

primrec lit_type :: "lit \<Rightarrow> prim_type" where
  "lit_type (LBool _) = Bool"
| "lit_type (LU8  _)  = Num U8"
| "lit_type (LU16 _)  = Num U16"
| "lit_type (LU32 _)  = Num U32"
| "lit_type (LU64 _)  = Num U64"

fun upcast_valid :: "num_type \<Rightarrow> num_type \<Rightarrow> bool" where
  "upcast_valid U8  U8  = True"
| "upcast_valid U8  U16 = True"
| "upcast_valid U8  U32 = True"
| "upcast_valid U8  U64 = True"
| "upcast_valid U16 U16 = True"
| "upcast_valid U16 U32 = True"
| "upcast_valid U16 U64 = True"
| "upcast_valid U32 U32 = True"
| "upcast_valid U32 U64 = True"
| "upcast_valid U64 U64 = True"
| "upcast_valid _   _   = False"

primrec prim_lbool where
  "prim_lbool (LBool b) = b"
| "prim_lbool (LU8 w) = False"
| "prim_lbool (LU16 w) = False"
| "prim_lbool (LU32 w) = False"
| "prim_lbool (LU64 w) = False"

definition prim_word_op
  where prim_word_op_def[simp]:
  "prim_word_op f8 f16 f32 f64 xs = (case (take 2 xs) of
      [LU8 x, LU8 y] \<Rightarrow> LU8 (f8 x y)
    | [LU16 x, LU16 y] \<Rightarrow> LU16 (f16 x y)
    | [LU32 x, LU32 y] \<Rightarrow> LU32 (f32 x y)
    | [LU64 x, LU64 y] \<Rightarrow> LU64 (f64 x y)
    | _ \<Rightarrow> LBool False)"

definition prim_word_comp
  where prim_word_comp_def[simp]:
  "prim_word_comp f8 f16 f32 f64 xs = (case (take 2 xs) of
      [LU8 x, LU8 y] \<Rightarrow> LBool (f8 x y)
    | [LU16 x, LU16 y] \<Rightarrow> LBool (f16 x y)
    | [LU32 x, LU32 y] \<Rightarrow> LBool (f32 x y)
    | [LU64 x, LU64 y] \<Rightarrow> LBool (f64 x y)
    | _ \<Rightarrow> LBool False)"

primrec eval_prim_op :: "prim_op \<Rightarrow> lit list \<Rightarrow> lit"
where
    "eval_prim_op Not xs = LBool (\<not> prim_lbool (hd xs))"
  | "eval_prim_op And xs = LBool (prim_lbool (hd xs) \<and> prim_lbool (xs ! 1))"
  | "eval_prim_op Or xs = LBool (prim_lbool (hd xs) \<or> prim_lbool (xs ! 1))"
  | "eval_prim_op (Eq _) xs = LBool (hd xs = xs ! 1)"
  | "eval_prim_op (NEq _) xs = LBool (hd xs \<noteq> xs ! 1)"
  | "eval_prim_op (Plus _) xs = prim_word_op (op +) (op +) (op +) (op +) xs"
  | "eval_prim_op (Minus _) xs = prim_word_op (op -) (op -) (op -) (op -) xs"
  | "eval_prim_op (Times _) xs = prim_word_op (op *) (op *) (op *) (op *) xs"
  | "eval_prim_op (Divide _) xs = prim_word_op checked_div checked_div checked_div checked_div  xs"
  | "eval_prim_op (Mod _) xs = prim_word_op checked_mod checked_mod checked_mod checked_mod xs"
  | "eval_prim_op (Gt _) xs = prim_word_comp greater greater greater greater xs"
  | "eval_prim_op (Lt _) xs = prim_word_comp less less less less xs"
  | "eval_prim_op (Le _) xs = prim_word_comp less_eq less_eq less_eq less_eq xs"
  | "eval_prim_op (Ge _) xs = prim_word_comp greater_eq greater_eq greater_eq greater_eq xs"
  | "eval_prim_op (BitAnd _) xs = prim_word_op bitAND bitAND bitAND bitAND xs"
  | "eval_prim_op (BitOr _) xs = prim_word_op bitOR bitOR bitOR bitOR xs"
  | "eval_prim_op (BitXor _) xs = prim_word_op bitXOR bitXOR bitXOR bitXOR xs"
  | "eval_prim_op (LShift _) xs = prim_word_op (checked_shift shiftl) (checked_shift shiftl)
        (checked_shift shiftl) (checked_shift shiftl) xs"
  | "eval_prim_op (RShift _) xs = prim_word_op (checked_shift shiftr) (checked_shift shiftr)
        (checked_shift shiftr) (checked_shift shiftr) xs"
  | "eval_prim_op (Complement _) xs = prim_word_op (\<lambda>x y. bitNOT x) (\<lambda>x y. bitNOT x)
        (\<lambda>x y. bitNOT x) (\<lambda>x y. bitNOT x) [hd xs, hd xs]"

lemma eval_prim_op_lit_type:
  "prim_op_type pop = (\<tau>s, \<tau>) \<Longrightarrow> map lit_type xs = \<tau>s
    \<Longrightarrow> lit_type (eval_prim_op pop xs) = \<tau>"
  by (cases pop, auto split: lit.split)

section {* Typing rules *}

(*
inductive subtyping :: "kind env \<Rightarrow> type \<Rightarrow> type \<Rightarrow> bool" ("_ \<turnstile> _ \<sqsubseteq> _" [30,0,0] 60) where
  tsum_subtyping: "\<lbrakk> set (map fst ts) = set (map fst ts')
                   ; \<forall> c c'. c \<in> set (map fst ts) \<longrightarrow> lookup c ts = lookup c ts' \<rbrakk> \<Longrightarrow> K \<turnstile> TSum ts \<sqsubseteq> TSum ts'"
*)

inductive typing :: "('f \<Rightarrow> poly_type) \<Rightarrow> kind env \<Rightarrow> ctx \<Rightarrow> 'f expr \<Rightarrow> type \<Rightarrow> bool"
          ("_, _, _ \<turnstile> _ : _" [30,0,0,0,20] 60)
      and typing_all :: "('f \<Rightarrow> poly_type) \<Rightarrow> kind env \<Rightarrow> ctx \<Rightarrow> 'f expr list \<Rightarrow> type list \<Rightarrow> bool"
          ("_, _, _ \<turnstile>* _ : _" [30,0,0,0,20] 60) where

  typing_var    : "\<lbrakk> K \<turnstile> \<Gamma> \<leadsto>w singleton (length \<Gamma>) i t
                   ; i < length \<Gamma>
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Var i : t"

| typing_afun   : "\<lbrakk> \<Xi> f = (K', t, u)
                   ; list_all2 (kinding K) ts K'
                   ; K' \<turnstile> TFun t u wellformed
                   ; K \<turnstile> \<Gamma> consumed
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> AFun f ts : instantiate ts (TFun t u)"

| typing_fun    : "\<lbrakk> \<Xi>, K', [Some t] \<turnstile> f : u
                   ; K \<turnstile> \<Gamma> consumed
                   ; K' \<turnstile> t wellformed
                   ; list_all2 (kinding K) ts K'
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Fun f ts : instantiate ts (TFun t u)"

| typing_app    : "\<lbrakk> K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2
                   ; \<Xi>, K, \<Gamma>1 \<turnstile> a : TFun x y
                   ; \<Xi>, K, \<Gamma>2 \<turnstile> b : x
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> App a b : y"

| typing_con    : "\<lbrakk> \<Xi>, K, \<Gamma> \<turnstile> x : t
                   ; (tag, t, False) \<in> set ts
                   ; K \<turnstile>* (map (fst \<circ> snd) ts) wellformed
                   ; distinct (map fst ts)
                   ; map fst ts = map fst ts'
                   ; map (fst \<circ> snd) ts = map (fst \<circ> snd) ts'
                   ; list_all2 (\<lambda>x y. snd (snd y) \<longrightarrow> snd (snd x)) ts ts'
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Con ts tag x : TSum ts'"

| typing_cast   : "\<lbrakk> \<Xi>, K, \<Gamma> \<turnstile> e : TPrim (Num \<tau>)
                   ; upcast_valid \<tau> \<tau>'
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Cast \<tau>' e : TPrim (Num \<tau>')"

| typing_tuple  : "\<lbrakk> K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2
                   ; \<Xi>, K, \<Gamma>1 \<turnstile> t : T
                   ; \<Xi>, K, \<Gamma>2 \<turnstile> u : U
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Tuple t u : TProduct T U"

| typing_split  : "\<lbrakk> K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2
                   ; \<Xi>, K, \<Gamma>1 \<turnstile> x : TProduct t u
                   ; \<Xi>, K, (Some t)#(Some u)#\<Gamma>2 \<turnstile> y : t'
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Split x y : t'"

| typing_let    : "\<lbrakk> K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2
                   ; \<Xi>, K, \<Gamma>1 \<turnstile> x : t
                   ; \<Xi>, K, (Some t # \<Gamma>2) \<turnstile> y : u
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Let x y : u"

| typing_letb   : "\<lbrakk> split_bang K is \<Gamma> \<Gamma>1 \<Gamma>2
                   ; \<Xi>, K, \<Gamma>1 \<turnstile> x : t
                   ; \<Xi>, K, (Some t # \<Gamma>2) \<turnstile> y : u
                   ; K \<turnstile> t :\<kappa> k
                   ; E \<in> k
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> LetBang is x y : u"

| typing_case   : "\<lbrakk> K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2
                   ; \<Xi>, K, \<Gamma>1 \<turnstile> x : TSum ts
                   ; (tag, (t,False)) \<in> set ts
                   ; \<Xi>, K, (Some t # \<Gamma>2) \<turnstile> a : u
                   ; \<Xi>, K, (Some (TSum (tagged_list_update tag (t, True) ts)) # \<Gamma>2) \<turnstile> b : u
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Case x tag a b : u"

| typing_esac   : "\<lbrakk> \<Xi>, K, \<Gamma> \<turnstile> x : TSum ts
                   ; [(_, (t,False))] = filter (HOL.Not \<circ> snd \<circ> snd) ts
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Esac x : t"

| typing_if     : "\<lbrakk> K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2
                   ; \<Xi>, K, \<Gamma>1 \<turnstile> x : TPrim Bool
                   ; \<Xi>, K, \<Gamma>2 \<turnstile> a : t
                   ; \<Xi>, K, \<Gamma>2 \<turnstile> b : t
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> If x a b : t"

| typing_prim   : "\<lbrakk> \<Xi>, K, \<Gamma> \<turnstile>* args : map TPrim ts
                   ; prim_op_type oper = (ts,t)
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Prim oper args : TPrim t"

| typing_lit    : "\<lbrakk> K \<turnstile> \<Gamma> consumed
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Lit l : TPrim (lit_type l)"

| typing_unit   : "\<lbrakk> K \<turnstile> \<Gamma> consumed
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Unit : TUnit"

| typing_struct : "\<lbrakk> \<Xi>, K, \<Gamma> \<turnstile>* es : ts
                   ; distinct ns
                   ; length ns = length ts
                   ; ts' = (zip ns (zip ts (replicate (length ts) False)))
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Struct ts es : TRecord ts' Unboxed"

| typing_member : "\<lbrakk> \<Xi>, K, \<Gamma> \<turnstile> e : TRecord ts s
                   ; K \<turnstile> TRecord ts s :\<kappa> k
                   ; S \<in> k
                   ; f < length ts
                   ; ts ! f = (n, t, False)
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Member e f : t"

| typing_take   : "\<lbrakk> K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2
                   ; \<Xi>, K, \<Gamma>1 \<turnstile> e : TRecord ts s
                   ; sigil_perm s \<noteq> Some ReadOnly
                   ; f < length ts
                   ; ts ! f = (n, t, False)
                   ; K \<turnstile> t :\<kappa> k
                   ; S \<in> k \<or> taken
                   ; \<Xi>, K, (Some t # Some (TRecord (ts [f := (n,t,taken)]) s) # \<Gamma>2) \<turnstile> e' : u
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Take e f e' : u"

| typing_put    : "\<lbrakk> K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2
                   ; \<Xi>, K, \<Gamma>1 \<turnstile> e : TRecord ts s
                   ; sigil_perm s \<noteq> Some ReadOnly
                   ; f < length ts
                   ; ts ! f = (n, t, taken)
                   ; K \<turnstile> t :\<kappa> k
                   ; D \<in> k \<or> taken
                   ; \<Xi>, K, \<Gamma>2 \<turnstile> e' : t
                   \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile> Put e f e' : TRecord (ts [f := (n,t,False)]) s"

| typing_all_empty : "\<Xi>, K, empty n \<turnstile>* [] : []"

| typing_all_cons  : "\<lbrakk> K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2
                      ; \<Xi>, K, \<Gamma>1 \<turnstile>  e  : t
                      ; \<Xi>, K, \<Gamma>2 \<turnstile>* es : ts
                      \<rbrakk> \<Longrightarrow> \<Xi>, K, \<Gamma> \<turnstile>* (e # es) : (t # ts)"


inductive_cases typing_num     [elim]: "\<Xi>, K, \<Gamma> \<turnstile> e : TPrim (Num \<tau>)"
inductive_cases typing_bool    [elim]: "\<Xi>, K, \<Gamma> \<turnstile> e : TPrim Bool"
inductive_cases typing_varE    [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Var i : \<tau>"
inductive_cases typing_appE    [elim]: "\<Xi>, K, \<Gamma> \<turnstile> App x y : \<tau>"
inductive_cases typing_litE    [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Lit l : \<tau>"
inductive_cases typing_funE    [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Fun f ts : \<tau>"
inductive_cases typing_afunE   [elim]: "\<Xi>, K, \<Gamma> \<turnstile> AFun f ts : \<tau>"
inductive_cases typing_ifE     [elim]: "\<Xi>, K, \<Gamma> \<turnstile> If c t e : \<tau>"
inductive_cases typing_conE    [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Con ts t e : \<tau>"
inductive_cases typing_unitE   [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Unit : \<tau>"
inductive_cases typing_primE   [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Prim p es : \<tau>"
inductive_cases typing_memberE [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Member e f : \<tau>"
inductive_cases typing_tupleE  [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Tuple a b : \<tau>"
inductive_cases typing_caseE   [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Case x t m n : \<tau>"
inductive_cases typing_esacE   [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Esac e : \<tau>"
inductive_cases typing_castE   [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Cast t e : \<tau>"
inductive_cases typing_letE    [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Let a b : \<tau>"
inductive_cases typing_structE [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Struct ts es : \<tau>"
inductive_cases typing_letbE   [elim]: "\<Xi>, K, \<Gamma> \<turnstile> LetBang vs a b : \<tau>"
inductive_cases typing_takeE   [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Take x f e : \<tau>"
inductive_cases typing_putE    [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Put x f e : \<tau>"
inductive_cases typing_splitE  [elim]: "\<Xi>, K, \<Gamma> \<turnstile> Split x e : \<tau>"
inductive_cases typing_all_emptyE [elim]: "\<Xi>, K, \<Gamma> \<turnstile>* []       : \<tau>s"
inductive_cases typing_all_consE  [elim]: "\<Xi>, K, \<Gamma> \<turnstile>* (x # xs) : \<tau>s"

section {* Syntax structural judgements *}

subsection {* A-normal form *}

inductive atom ::"'f expr \<Rightarrow> bool" where
  "atom (Var x)"
| "atom (Fun f ts)"
| "atom (AFun f ts)"
| "atom (Prim p (map Var is))"
| "atom (Con ts n (Var x))"
| "atom (Struct ts (map Var is))"
| "atom (Cast t (Var x))"
| "atom (Member (Var x) f)"
| "atom Unit"
| "atom (Lit l)"
| "atom (Tuple (Var x) (Var y))"
| "atom (Esac (Var x))"
| "atom (App (Var a) (Var b))"
| "atom (App (Fun f ts) (Var b))"
| "atom (App (AFun f ts) (Var b))"
| "atom (Put (Var x) f (Var y))"

inductive a_normal :: "'f expr \<Rightarrow> bool" where
  "\<lbrakk> atom x \<rbrakk> \<Longrightarrow> a_normal x"
| "\<lbrakk> atom x ; a_normal y \<rbrakk> \<Longrightarrow> a_normal (Let x y)"
| "\<lbrakk> a_normal x ; a_normal y \<rbrakk> \<Longrightarrow> a_normal (LetBang is x y)"
| "\<lbrakk> a_normal m ; a_normal n \<rbrakk> \<Longrightarrow> a_normal (Case (Var x) t m n)"
| "\<lbrakk> a_normal t ; a_normal e \<rbrakk> \<Longrightarrow> a_normal (If (Var x) t e)"
| "\<lbrakk> a_normal y \<rbrakk> \<Longrightarrow> a_normal (Split (Var x) y)"
| "\<lbrakk> a_normal y \<rbrakk> \<Longrightarrow> a_normal (Take (Var x) f y)"

inductive_cases a_normal_E:  "a_normal x"
inductive_cases a_normal_LetE:  "a_normal (Let x y)"
inductive_cases a_normal_LetBangE: "a_normal (LetBang is x y)"
inductive_cases a_normal_CaseE: "a_normal (Case x t m n)"
inductive_cases a_normal_IfE: "a_normal (If x t e)"
inductive_cases a_normal_Split: "a_normal (Split x y)"
inductive_cases a_normal_TakeE:  "a_normal (Take x f e)"

section {* Representation Types (for use in C-refinement) *}


datatype repr = RPtr repr
              | RCon name "repr list"
              | RFun
              | RPrim prim_type
              | RSum "(name \<times> repr) list"
              | RProduct "repr" "repr"
              | RRecord "repr list"
              | RUnit

fun type_repr :: "type \<Rightarrow> repr" where
  "type_repr (TFun t t')          = RFun"
| "type_repr (TPrim t)            = RPrim t"
| "type_repr (TSum ts)            = RSum (map (\<lambda>(a,b,_).(a, type_repr b)) ts)"
| "type_repr (TProduct a b)       = RProduct (type_repr a) (type_repr b)"
| "type_repr (TCon n ts Unboxed)  = RCon n (map type_repr ts)"
| "type_repr (TCon n ts _)        = RPtr (RCon n (map type_repr ts))"
| "type_repr (TRecord ts Unboxed) = RRecord (map (\<lambda>(_,b,_). type_repr b) ts)"
| "type_repr (TRecord ts _)       = RPtr (RRecord (map (\<lambda>(_,b,_). type_repr b) ts))"
| "type_repr (TUnit)              = RUnit"


section {* Kinding lemmas *}

lemma supersumption:
fixes k' :: kind
assumes k_is_superset : "k' \<subseteq> k"
shows "K \<turnstile>  t  :\<kappa> k  \<Longrightarrow> K \<turnstile>  t  :\<kappa> k'"
and   "K \<turnstile>* ts :\<kappa> k  \<Longrightarrow> K \<turnstile>* ts :\<kappa> k'"
and   "K \<turnstile>* fs :\<kappa>r k \<Longrightarrow> K \<turnstile>* fs :\<kappa>r k'"
using k_is_superset proof (induct rule: kinding_kinding_all_kinding_record.inducts)
qed (auto intro: subset_trans kinding_kinding_all_kinding_record.intros)


lemma kind_top:
shows "k \<subseteq> {D, S, E}"
by (force intro: kind_comp.exhaust)

lemma kinding_all_nth:
fixes n :: nat
assumes "K \<turnstile>* ts :\<kappa> k"
and     "n < length ts"
shows   "K \<turnstile> (ts ! n) :\<kappa> k"
using assms proof (induct ts arbitrary: n)
     case Nil  then show ?case by auto
next case Cons then show ?case by (case_tac n, auto)
qed

lemma kinding_all_set:
shows "(K \<turnstile>* ts :\<kappa> k) = (\<forall> t \<in> set ts. K \<turnstile> t :\<kappa> k)"
proof (rule iffI)
     assume "K \<turnstile>* ts :\<kappa> k"
then show   "\<forall> t \<in> set ts. K \<turnstile> t :\<kappa> k"
     by (rule kinding_kinding_all_kinding_record.inducts, simp+)

next assume "\<forall> t \<in> set ts. K \<turnstile> t :\<kappa> k"
then show   "K \<turnstile>* ts :\<kappa> k"
     by (induct ts, auto intro: kinding_kinding_all_kinding_record.intros)
qed

lemma kinding_all_subset:
assumes "K \<turnstile>* ts :\<kappa> k"
and     "set us \<subseteq> set ts"
shows   "K \<turnstile>* us :\<kappa> k"
using assms by (auto simp add: kinding_all_set)

lemma kinding_all_list_all:
  shows "(K \<turnstile>* ts :\<kappa> k) = list_all (\<lambda>t. K \<turnstile> t :\<kappa> k) ts"
  by (induct ts; fastforce simp add: kind_all_empty kind_all_cons)

lemma kinding_typelist_wellformed_elem:
  assumes "K \<turnstile>* ts :\<kappa> k"
    and "t \<in> set ts"
  shows "K \<turnstile> t wellformed"
  using assms kinding_all_set by auto

lemma kinding_record_wellformed:
  assumes "K \<turnstile>* ts :\<kappa>r k"
    and "(name,t,taken) \<in> set ts"
  shows "K \<turnstile> t wellformed"
  using assms
  by (induct ts; force)

lemma kinding_record_wellformed_nth:
assumes "K \<turnstile>* ts :\<kappa>r k"
and     "ts ! n = (name,t,taken)"
and     "n < length ts"
shows   "K \<turnstile> t wellformed"
using assms(1)
  and assms(2) [THEN sym]
  and assms(3) by (force intro: kinding_record_wellformed [simplified]
                         simp:  set_conv_nth)

lemma kinding_all_record:
  assumes
    "K \<turnstile>* ts :\<kappa> k"
    "length ns = length ts"
  shows
    "K \<turnstile>* zip ns (zip ts (replicate (length ts) False)) :\<kappa>r k"
  using assms
proof (induct ts arbitrary: ns)
  case (Cons a ts)
  moreover then obtain n ns' where "ns = n # ns'"
    by (metis Suc_length_conv length_Cons)
  ultimately show ?case
    by (fastforce simp add: length_Cons intro: kinding_kinding_all_kinding_record.intros)
qed (force intro: kinding_kinding_all_kinding_record.intros)

lemma kinding_all_record':
  assumes "K \<turnstile>* map (fst \<circ> snd) ts :\<kappa> k"
  shows   "K \<turnstile>* ts :\<kappa>r k"
  using assms
proof (induct ts)
  case (Cons a ts)
  then show ?case
    apply clarsimp
    apply (case_tac a)
    apply (case_tac c)
     apply (auto intro: kinding_kinding_all_kinding_record.intros)
    done
qed (force intro: kinding_kinding_all_kinding_record.intros)

lemma kinding_record_update:
  assumes "K \<turnstile>* ts :\<kappa>r k"
    and "ts ! n = (name, a, b)"
    and "K \<turnstile> a :\<kappa> k'"
  shows "K \<turnstile>* (ts[ n := (name, a, False)]) :\<kappa>r (k \<inter> k')"
  using assms
proof (induct ts arbitrary: n)
  case (Cons a ts)
  then show ?case
    by (cases n; force elim!: kind_record_consE
        intro!: kinding_kinding_all_kinding_record.intros
        intro: supersumption)
qed (force intro: kinding_kinding_all_kinding_record.intros)
    

lemma sigil_kind_writable:
  assumes "sigil_perm s = Some Writable"
    and "\<And>r. k \<subseteq> sigil_kind (Boxed Writable r)"
  shows "k \<subseteq> sigil_kind s"
  using assms
  by (case_tac s rule: sigil_cases, auto)

section {* Bang lemmas *}

lemma bang_sigil_idempotent:
shows "bang_sigil (bang_sigil s) = bang_sigil s"
  by (cases s rule: bang_sigil.cases, simp+)

lemma bang_idempotent:
shows "bang (bang \<tau>) = bang \<tau>"
by (force intro: bang.induct [where P = "\<lambda> \<tau> . bang (bang \<tau>) = bang \<tau>"]
          simp:  bang_sigil_idempotent)

lemma bang_sigil_kind:
shows "{D , S} \<subseteq> sigil_kind (bang_sigil s)"
  by (case_tac s rule: bang_sigil.cases, auto)

lemma bang_kind:
shows "K \<turnstile>  t  :\<kappa> k \<Longrightarrow> K \<turnstile>  bang t                       :\<kappa> {D, S}"
and   "K \<turnstile>* ts :\<kappa> k \<Longrightarrow> K \<turnstile>* map bang ts                  :\<kappa> {D, S}"
and   "K \<turnstile>* fs :\<kappa>r k \<Longrightarrow> K \<turnstile>* map (\<lambda>(n,t,b). (n, bang t, b)) fs :\<kappa>r {D, S}"
  apply (induct rule: kinding_kinding_all_kinding_record.inducts)
  by (auto intro: kinding_kinding_all_kinding_record.intros
           intro!: bang_sigil_kind
           simp add: case_prod_unfold comp_def)

section {* Typing lemmas *}

lemma variant_element_subtyping_mapping:
  assumes tag_in_ts: "(tag, t, b) \<in> set ts"
    and distinct_ts: "distinct (map fst ts')"
    and tags_same: "map fst ts = map fst ts'"
    and types_same: "map (fst \<circ> snd) ts = map (fst \<circ> snd) ts'"
    and taken_subcond: "list_all2 (\<lambda>x y. snd (snd y) \<longrightarrow> snd (snd x)) ts ts'"
  shows "\<exists>b'. (tag, t, b') \<in> set ts' \<and> (b' \<longrightarrow> b)"
proof -
  obtain i
    where i_in_bounds: "i < length ts"
      and ts_at_i: "ts ! i = (tag, t, b)"
    by (meson tag_in_ts in_set_conv_nth)
  then obtain tag' t' b' where "ts' ! i = (tag', t', b')"
    using prod_cases3 by blast
  then have ts'_at_i: "ts' ! i = (tag, t, b')"
    by (metis (no_types, lifting) ts_at_i comp_apply fst_conv i_in_bounds length_map nth_map snd_conv tags_same types_same)
  moreover have "b' \<longrightarrow> b"
  proof -
    have "snd (snd (ts' ! i)) \<longrightarrow> snd (snd (ts ! i))"
      using taken_subcond i_in_bounds
      by (simp add: list_all2_conv_all_nth)
    then show ?thesis
      using ts_at_i ts'_at_i by force
  qed
  ultimately show ?thesis
    by (metis i_in_bounds length_map nth_mem tags_same)
qed

section {* Instantiation *}

lemma instantiate_bang [simp]:
shows "instantiate \<delta> (bang \<tau>) = bang (instantiate \<delta> \<tau>)"
by (force intro: bang.induct [where P = "\<lambda> \<tau>. instantiate \<delta> (bang \<tau>) = bang (instantiate \<delta> \<tau>)"]
          simp:  bang_idempotent)

find_theorems name: kinding_kinding_all_kinding_record

lemma instantiate_instantiate [simp]:
assumes "list_all2 (kinding K') \<delta>' K"
and     "length K' = length \<delta>"
shows   "K \<turnstile> x wellformed \<Longrightarrow> instantiate \<delta> (instantiate \<delta>' x) = instantiate (map (instantiate \<delta>) \<delta>') x"
using assms proof (induct x arbitrary: \<delta>' rule: instantiate.induct)

next case 3 then show ?case by (force simp: set_conv_nth
                                      dest: kinding_all_nth)
next case 8 then show ?case by (fastforce dest: kinding_record_wellformed)
next case (6 \<delta> ps) note IH   = this(1)
                   and  REST = this(2-)
  from REST show ?case apply (clarsimp)
                       apply (rule IH, simp, simp)
                       apply (auto simp:  set_conv_nth comp_def
                                   intro: kind_tsum
                                   dest!: prod_in_set(2)
                                   dest:  kinding_all_nth [ where ts = "map (fst \<circ> snd) ts" for ts
                                                          , simplified])+
                       apply (erule kinding.cases; simp_all)
                       apply (bestsimp dest: kinding_all_nth [ where ts = "map (fst \<circ> snd) ps" and n = "i" for i ps
                                                             , simplified]
                                             sym [ where ?t = "ps ! i" for i ])
                       done
qed (force dest: list_all2_lengthD)+

lemma instantiate_tprim [simp]:
shows "instantiate \<delta> \<circ> TPrim = TPrim"
by (rule ext, simp)


lemma instantiate_nothing:
shows "instantiate [] e = e"
by (induct e) (auto simp: prod_set_defs intro: map_idI)

lemma instantiate_nothing_id[simp]:
shows "instantiate [] = id"
by (rule ext, simp add: instantiate_nothing)

lemma instantiate_ctx_nothing:
shows "instantiate_ctx [] e = e"
unfolding instantiate_ctx_def
by (induct e, auto simp: map_option.id [simplified id_def])

lemma instantiate_ctx_nothing_id[simp]:
shows "instantiate_ctx [] = id"
by (rule ext, simp add: instantiate_ctx_nothing)

lemma specialise_nothing:
shows "specialise [] e = e"
by (induct e) (auto simp: prod_set_defs intro: map_idI)

lemma specialise_nothing_id[simp]:
shows "specialise [] = id"
by (rule ext, simp add: specialise_nothing)

lemmas typing_struct_instantiate = typing_struct [where ts = "map (instantiate \<delta>) ts" for ts, simplified]

lemma instantiate_over_variants_subvariants:
  assumes tags_same: "map fst ts = map fst ts'"
    and types_same: "map (fst \<circ> snd) ts = map (fst \<circ> snd) ts'"
  shows "map (\<lambda>(n, t, _). (n, type_repr t)) (map (\<lambda>(c, t, b). (c, instantiate \<tau>s t, b)) ts) =
         map (\<lambda>(c, t, _). (c, type_repr t)) (map (\<lambda>(c, t, b). (c, instantiate \<tau>s t, b)) ts')"
proof -
  have f1: "((\<lambda>(n, t, _). (n, type_repr t)) \<circ> (\<lambda>(c, t, b). (c, instantiate \<tau>s t, b))) = (\<lambda>(n, t, _). (n, type_repr (instantiate \<tau>s t)))"
    by fastforce
  have f2: "(\<lambda>(n, t, _). (n, type_repr (instantiate \<tau>s t))) = (\<lambda>p. (fst p, (type_repr \<circ> (instantiate \<tau>s) \<circ> (fst \<circ> snd)) p))"
    by fastforce

  have "(map (type_repr \<circ> (instantiate \<tau>s) \<circ> (fst \<circ> snd)) ts) = (map (type_repr \<circ> (instantiate \<tau>s) \<circ> (fst \<circ> snd)) ts')"
    using types_same map_map by metis
  then have "map (\<lambda>(n, t, _). (n, type_repr (instantiate \<tau>s t))) ts =
          map (\<lambda>(n, t, _). (n, type_repr (instantiate \<tau>s t))) ts'"
    by (fastforce intro: pair_list_eqI simp add: f2 comp_def tags_same)
  then show ?thesis
    by (simp add: f1)
qed

subsection {* substitutivity *}

lemma substitutivity:
fixes \<delta>    :: "type substitution"
and   K K' :: "kind env"
assumes well_kinded: "list_all2 (kinding K') \<delta> K"
shows "K \<turnstile> t :\<kappa> k    \<Longrightarrow> K' \<turnstile>  instantiate \<delta> t                       :\<kappa> k"
and   "K \<turnstile>* ts :\<kappa> k  \<Longrightarrow> K' \<turnstile>* map (instantiate \<delta>) ts                :\<kappa> k"
and   "K \<turnstile>* fs :\<kappa>r k \<Longrightarrow> K' \<turnstile>* map (\<lambda>(n,a,b). (n,instantiate \<delta> a, b)) fs :\<kappa>r k"
using well_kinded proof (induct rule: kinding_kinding_all_kinding_record.inducts)
     case (kind_tvar k K i)
       assume "list_all2 (kinding K') \<delta> K"
       and    "i < length K"
       and    "k \<subseteq> K ! i"
       moreover   then have "i < length \<delta>" by (auto dest: list_all2_lengthD)
       ultimately also have "K' \<turnstile> (\<delta> ! i) :\<kappa> (K ! i)" by (auto intro: list_all2_nthD)
       ultimately show ?case by (auto intro: supersumption)
next case (kind_tvarb k i K)
       assume "list_all2 (kinding K') \<delta> K"
       and    "i < length K"
       and    "k \<subseteq> {D, S}"
       moreover   then have "i < length \<delta>" by (auto dest: list_all2_lengthD)
       ultimately also have "K' \<turnstile> (\<delta> ! i) :\<kappa> (K ! i)" by (auto intro: list_all2_nthD)
       ultimately show ?case by (auto intro: supersumption bang_kind)
qed (auto intro: kinding_kinding_all_kinding_record.intros)



lemma list_all2_substitutivity:
fixes \<delta>    :: "type substitution"
and   K K' :: "kind env"
assumes well_kinded: "list_all2 (kinding K') \<delta> K"
shows "list_all2 (kinding K) ts ks \<Longrightarrow> list_all2 (kinding K') (map (instantiate \<delta>) ts) ks"
by ( induct rule: list_all2_induct
   , auto dest: substitutivity [OF well_kinded])

subsection {* Instantiation of contexts *}

lemma instantiate_ctx_weaken:
assumes "K \<turnstile> \<Gamma> \<leadsto>w \<Gamma>'"
and     "list_all2 (kinding K') \<delta> K"
shows   "K' \<turnstile> instantiate_ctx \<delta> \<Gamma> \<leadsto>w instantiate_ctx \<delta> \<Gamma>'"
using assms(1) [simplified weakening_def] and assms(2) proof (induct rule: list_all2_induct)
     case Nil  then show ?case by (simp add: instantiate_ctx_def weakening_def)
next case Cons then show ?case by (fastforce intro: weakening_comp.intros
                                             elim:  weakening_comp.cases
                                             simp:  instantiate_ctx_def
                                                    weakening_def
                                             dest:  substitutivity)
qed


lemma instantiate_ctx_empty [simplified, simp]:
shows "instantiate_ctx \<delta> (empty l) = empty l"
by (induct l, simp_all add: empty_def
                            instantiate_ctx_def)



lemma instantiate_ctx_singleton [simplified, simp]:
shows "instantiate_ctx \<delta> (singleton l i \<tau>) = singleton l i (instantiate \<delta> \<tau>)"
by (induct l arbitrary: i, simp_all add:   instantiate_ctx_def
                                           empty_def
                                    split: nat.split)

lemma instantiate_ctx_length [simp]:
shows "length (instantiate_ctx \<delta> \<Gamma>) = length \<Gamma>"
by (simp add: instantiate_ctx_def)

lemma instantiate_ctx_consumed [simplified]:
assumes "K \<turnstile> \<Gamma> consumed"
and     "list_all2 (kinding K') \<delta> K"
shows   "K' \<turnstile> instantiate_ctx \<delta> \<Gamma> consumed"
using assms by (auto intro: instantiate_ctx_weaken [where \<Gamma>' = "empty (length \<Gamma>)", simplified])

lemma map_option_instantiate_split_comp:
assumes "K \<turnstile> c \<leadsto> c1 \<parallel> c2"
and     "list_all2 (kinding K') \<delta> K"
shows   "K' \<turnstile> map_option (instantiate \<delta>) c \<leadsto> map_option (instantiate \<delta>) c1 \<parallel> map_option (instantiate \<delta>) c2"
using assms(1) by ( rule split_comp.cases
                  , auto elim: split_comp.cases
                         intro: substitutivity(1) assms(2) split_comp.intros)

lemma instantiate_ctx_split:
assumes "K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2"
and     "list_all2 (kinding K') \<delta> K"
shows   "K' \<turnstile> instantiate_ctx \<delta> \<Gamma> \<leadsto> instantiate_ctx \<delta> \<Gamma>1 | instantiate_ctx \<delta> \<Gamma>2"
  using assms
  by (auto intro: list_all3_map_over simp: map_option_instantiate_split_comp instantiate_ctx_def split_def)


lemma instantiate_ctx_split_bang:
  assumes "split_bang K is \<Gamma> \<Gamma>1 \<Gamma>2"
    and "list_all2 (kinding K') \<delta> K"
  shows "split_bang K' is (instantiate_ctx \<delta> \<Gamma>) (instantiate_ctx \<delta> \<Gamma>1) (instantiate_ctx \<delta> \<Gamma>2)"
  using assms
proof (induct rule: split_bang.induct)
  case split_bang_empty
  then show ?case by (auto simp: instantiate_ctx_def intro: split_bang.intros)
next
  case split_bang_cons
  then show ?case
    apply (auto
        simp add: instantiate_ctx_def split_bang_comp.simps map_option_instantiate_split_comp
        intro!: split_bang.intros)
    using substitutivity(1)
     apply fast+
    done
qed


lemma instantiate_ctx_cons [simp]:
shows   "instantiate_ctx \<delta> (Some x # \<Gamma>) = Some (instantiate \<delta> x) # instantiate_ctx \<delta> \<Gamma>"
by (simp add: instantiate_ctx_def)



section {* Lemmas about contexts, splitting and weakening *}

lemma pred_left_inverse_Suc:
  "pred \<circ> Suc = id"
  using Cogent.pred_def by auto

lemma pred_right_inverse_Suc_for_nonzero:
  "x \<noteq> 0 \<Longrightarrow> (Suc \<circ> pred) x = x"
  by (metis Cogent.pred_def comp_apply nat.case(2) not0_implies_Suc)

lemma set_pred_left_inverse_suc:
  "A = Suc ` B \<Longrightarrow> pred ` A = B"
  by (simp add: pred_left_inverse_Suc image_comp)

lemma set_pred_right_inverse_suc_for_nonzero:
  "0 \<notin> B \<Longrightarrow> A = pred ` B \<Longrightarrow> Suc ` A = B"
  by (metis (no_types) pred_right_inverse_Suc_for_nonzero image_comp id_apply image_cong image_id)


lemma Suc_mem_image_pred:
  "0 \<notin> js \<Longrightarrow> (Suc n \<in> js) = (n \<in> pred ` js)"
  apply (simp add: image_def pred_def)
  apply (auto elim: rev_bexI split: nat.split_asm)
  done

lemma Suc_mem_image_pred_remove:
  "(n \<in> pred ` Set.remove 0 js) = (Suc n \<in> js)"
  by (simp add: Suc_mem_image_pred[symmetric])


lemma empty_length[simp]:
  "length (empty n) = n"
  unfolding empty_def by simp

lemma singleton_length[simp]: "length (singleton n i t) = n"
  unfolding singleton_def by simp


subsection {* split *}

lemma split_length:
  assumes "K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2"
  shows "length \<Gamma> = length \<Gamma>1"
    and "length \<Gamma> = length \<Gamma>2"
  using assms
  by (simp add: split_def list_all3_iff)+

lemmas split_Cons1 = list_all3_Cons1[where P="split_comp K" for K, simplified split_def[symmetric]]
lemmas split_Cons2 = list_all3_Cons2[where P="split_comp K" for K, simplified split_def[symmetric]]
lemmas split_Cons3 = list_all3_Cons3[where P="split_comp K" for K, simplified split_def[symmetric]]

lemma split_bang_length:
  assumes "split_bang K is \<Gamma> \<Gamma>1 \<Gamma>2"
  shows "length \<Gamma> = length \<Gamma>1"
    and "length \<Gamma> = length \<Gamma>2"
  using assms
  by (induct rule: split_bang.inducts, force+)

lemma split_preservation_some:
  assumes splits: "K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2"
    and idx: "\<Gamma>1 ! i = Some t \<or> \<Gamma>2 ! i = Some t"
  shows "\<Gamma> ! i  = Some t"
  using assms
  by (induct arbitrary: i rule: split_induct; fastforce simp add: nth_Cons' elim: split_comp.cases)

lemma split_preserves_none:
  assumes splits: "K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2"
    and idx: "\<Gamma> ! i  = None"
  shows "\<Gamma>1 ! i = None"
    and "\<Gamma>2 ! i = None"
  using assms
  by (induct arbitrary: i rule: split_induct, (fastforce simp add: nth_Cons' elim: split_comp.cases)+)


lemma split_split_ctxs_come_from_input:
  assumes "K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2"
  shows "{t. Some t \<in> set \<Gamma>} = {t. Some t \<in> set \<Gamma>1} \<union> {t. Some t \<in> set \<Gamma>2}"
  using assms
proof (induct rule: split_induct)
  case (split_cons x xs a as b bs)
  moreover then have
    "x \<noteq> None \<longrightarrow> (x = a \<and> x = b) \<or> (a = None \<and> x = b) \<or> (x = a \<and> b = None)"
    "x = None \<longrightarrow> a = None \<and> b = None"
    by (fastforce simp add: split_comp.simps)+
  ultimately show ?case
    by auto
qed simp

subsection {* weaken *}

lemma weakening_length:
shows "K \<turnstile> \<Gamma> \<leadsto>w \<Gamma>' \<Longrightarrow> length \<Gamma> = length \<Gamma>'"
by (auto simp: weakening_def dest:list_all2_lengthD)

lemma weakening_cons:
shows "K \<turnstile> x # \<Gamma> \<leadsto>w x' # \<Gamma>' \<longleftrightarrow> weakening_comp K x x' \<and> K \<turnstile> \<Gamma> \<leadsto>w \<Gamma>'"
  by (auto simp: weakening_def)

lemma weakening_update:
  assumes  "K \<turnstile> \<Gamma> \<leadsto>w \<Gamma>'"
    and "weakening_comp K x y"
  shows "K \<turnstile> \<Gamma>[i := x] \<leadsto>w \<Gamma>'[i := y]"
  using assms
  unfolding weakening_def
  by (simp add: list_all2_update_cong)

lemma weakening_preservation_some:
assumes weak: "K \<turnstile> \<Gamma> \<leadsto>w \<Gamma>'"
and     idx:  "\<Gamma>' ! x = Some t"
shows   "\<Gamma>  ! x = Some t"
using weak[simplified weakening_def]
  and weakening_length[OF weak]
  and idx
  proof (induct arbitrary: x rule: list_all2_induct)
     case Nil                then show ?case by auto
next case (Cons x xs y ys a) then show ?case by (case_tac a, auto elim: weakening_comp.cases)
qed

lemma weakening_preserves_none:
assumes weak: "K \<turnstile> \<Gamma> \<leadsto>w \<Gamma>'"
and     idx:  "\<Gamma>  ! x = None"
shows   "\<Gamma>' ! x = None"
using weak[simplified weakening_def]
  and weakening_length[OF weak]
  and idx
  proof (induct arbitrary: x rule: list_all2_induct)
     case Nil                then show ?case by auto
next case (Cons x xs y ys a) then show ?case by (case_tac a, auto elim: weakening_comp.cases)
qed

lemma weakening_nth:
assumes weak: "K \<turnstile> \<Gamma> \<leadsto>w \<Gamma>'"
and           "i < length \<Gamma>"
shows         "weakening_comp K (\<Gamma>!i) (\<Gamma>'!i)"
using assms by (auto simp add: weakening_def dest: list_all2_nthD)

lemma weakening_implies_wellformed:
  assumes "K \<turnstile> \<Gamma> \<leadsto>w \<Gamma>'"
  shows "Some t \<in> set \<Gamma> \<Longrightarrow> K \<turnstile> t wellformed"
  and "Some t \<in> set \<Gamma>' \<Longrightarrow> K \<turnstile> t wellformed"
  using assms
  unfolding weakening_def
  by (induct rule: list_all2_induct, (fastforce simp add: weakening_comp.simps)+)

lemma weakening_refl:
  assumes "\<And>t. Some t \<in> set \<Gamma> \<Longrightarrow> K \<turnstile> t wellformed"
  shows "K \<turnstile> \<Gamma> \<leadsto>w \<Gamma>"
  using assms
  by (auto simp add: weakening_def weakening_comp.simps list_all2_same)

subsection {* interactions between splitting and weakening *}

lemma split_weaken_comp:
  assumes "K \<turnstile> a \<leadsto> a1 \<parallel> a2"
    and "weakening_comp K a wa"
  shows "\<exists>wa1 wa2. (K \<turnstile> wa \<leadsto> wa1 \<parallel> wa2) \<and> (weakening_comp K a1 wa1) \<and> (weakening_comp K a2 wa2)"
  using assms
  apply (cases a1)
   apply (fastforce simp add: split_comp.simps weakening_comp.simps)
  apply (cases a2)
   apply (fastforce simp add: split_comp.simps weakening_comp.simps)
  apply (clarsimp simp add: split_comp.simps weakening_comp.simps, blast)
  done

lemma split_weaken:
  assumes "K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2"
    and "K \<turnstile> \<Gamma> \<leadsto>w w\<Gamma>"
  shows "\<exists>w\<Gamma>1 w\<Gamma>2. (K \<turnstile> w\<Gamma> \<leadsto> w\<Gamma>1 | w\<Gamma>2) \<and> (K \<turnstile> \<Gamma>1 \<leadsto>w w\<Gamma>1) \<and> (K \<turnstile> \<Gamma>2 \<leadsto>w w\<Gamma>2)"
  using assms
proof (induct \<Gamma> arbitrary: w\<Gamma> \<Gamma>1 \<Gamma>2)
  case Nil
  then show ?case
    using split_length weakening_length by fastforce
next
  case (Cons a \<Gamma>')
  then obtain a1 \<Gamma>1' a2 \<Gamma>2' wa w\<Gamma>'
    where ctx_simps:
      "\<Gamma>1 = a1 # \<Gamma>1'"
      "\<Gamma>2 = a2 # \<Gamma>2'"
      "w\<Gamma> = wa # w\<Gamma>'"
    using weakening_def split_length
    by (metis list.rel_distinct(2) length_0_conv neq_Nil_conv)

  have prems_elims:
    "K \<turnstile> \<Gamma>' \<leadsto> \<Gamma>1' | \<Gamma>2'"
    "K \<turnstile> a \<leadsto> a1 \<parallel> a2"
    "K \<turnstile> \<Gamma>' \<leadsto>w w\<Gamma>'"
    "weakening_comp K a wa"
    using Cons.prems
    by (fastforce simp add: split_def elim: list_all3.cases simp add: weakening_def ctx_simps)+
  then obtain wa1 wa2
    where weak_of_split_comps:
      "K \<turnstile> wa \<leadsto> wa1 \<parallel> wa2"
      "weakening_comp K a1 wa1"
      "weakening_comp K a2 wa2"
    using split_weaken_comp by blast

  obtain w\<Gamma>1' w\<Gamma>2'
    where ih_on_subctxs:
      "K \<turnstile> w\<Gamma>' \<leadsto> w\<Gamma>1' | w\<Gamma>2'"
      "K \<turnstile> \<Gamma>1' \<leadsto>w w\<Gamma>1'"
      "K \<turnstile> \<Gamma>2' \<leadsto>w w\<Gamma>2'"
    using prems_elims Cons.hyps weakening_def split_cons prems_elims
    by blast

  have "K \<turnstile> wa # w\<Gamma>' \<leadsto> wa1 # w\<Gamma>1' | wa2 # w\<Gamma>2'"
    and "K \<turnstile> a1 # \<Gamma>1' \<leadsto>w wa1 # w\<Gamma>1'"
    and "K \<turnstile> a2 # \<Gamma>2' \<leadsto>w wa2 # w\<Gamma>2'"
    using ih_on_subctxs weak_of_split_comps split_cons weakening_def list.rel_intros(2)
    by metis+
  then show ?case
    using ctx_simps by blast
qed


lemma weaken_and_split_comp:
  assumes "K \<turnstile> a \<leadsto> a1 \<parallel> a2"
    and "weakening_comp K a1 wa1"
    and "weakening_comp K a2 wa2"
  shows "\<exists>wa. weakening_comp K a wa \<and> K \<turnstile> wa \<leadsto> wa1 \<parallel> wa2"
  using assms
  by (fastforce simp add: split_comp.simps weakening_comp.simps)

lemma weaken_and_split:
  assumes "K \<turnstile> \<Gamma> \<leadsto> \<Gamma>1 | \<Gamma>2"
    and "K \<turnstile> \<Gamma>1 \<leadsto>w w\<Gamma>1"
    and "K \<turnstile> \<Gamma>2 \<leadsto>w w\<Gamma>2"
  shows "\<exists>w\<Gamma>. (K \<turnstile> \<Gamma> \<leadsto>w w\<Gamma>) \<and> (K \<turnstile> w\<Gamma> \<leadsto> w\<Gamma>1 | w\<Gamma>2)"
  using assms
proof (induct arbitrary: w\<Gamma>1 w\<Gamma>2 rule: split_induct)
  case (split_cons a \<Gamma> a1 \<Gamma>1 a2 \<Gamma>2)

  obtain wa1 w\<Gamma>1' wa2 w\<Gamma>2'
    where ctx_simps:
      "w\<Gamma>1 = wa1 # w\<Gamma>1'"
      "w\<Gamma>2 = wa2 # w\<Gamma>2'"
    by (metis split_cons.prems list_all2_Cons1 weakening_def)
  have subweakenings:
    "weakening_comp K a1 wa1"
    "K \<turnstile> \<Gamma>1 \<leadsto>w w\<Gamma>1'"
    "weakening_comp K a2 wa2"
    "K \<turnstile> \<Gamma>2 \<leadsto>w w\<Gamma>2'"
    by (metis ctx_simps list.rel_inject(2) split_cons.prems weakening_def)+
  then obtain w\<Gamma>' wa
    where IHsplitsweakens:
      "K \<turnstile> wa \<leadsto> wa1 \<parallel> wa2"
      "K \<turnstile> w\<Gamma>' \<leadsto> w\<Gamma>1'| w\<Gamma>2'"
      "weakening_comp K a wa"
      "K \<turnstile> \<Gamma> \<leadsto>w w\<Gamma>'"
    using split_cons.hyps weaken_and_split_comp
    by blast
  then have
    "K \<turnstile> wa # w\<Gamma>' \<leadsto> wa1 # w\<Gamma>1' | wa2 # w\<Gamma>2'"
    "K \<turnstile> a # \<Gamma> \<leadsto>w wa # w\<Gamma>'"
    unfolding weakening_def
    using IHsplitsweakens
    by (simp add: split_def weakening_def)+
  then show ?case
    using ctx_simps by blast
qed (force simp add: weakening_def split_def)

lemma weaken_and_split_bang_comp:
  assumes "K , dobang \<turnstile> a \<leadsto>b a1 \<parallel> a2"
    and "weakening_comp K a1 wa1"
    and "weakening_comp K a2 wa2"
  shows "\<exists>dobang' wa. (dobang' \<longrightarrow> dobang \<and> (\<exists>t. a = Some t) \<and> wa = a) \<and> (weakening_comp K a wa) \<and> (K , dobang' \<turnstile> wa \<leadsto>b wa1 \<parallel> wa2)"
  using assms
proof (cases rule: split_bang_comp.cases)
  case none
  then show ?thesis
    using assms
    apply -
    apply (erule split_comp.cases)
       apply (fastforce simp add: split_comp.simps weakening_comp.simps split_bang_comp.simps)
      apply (cases wa1; auto simp add: weakening_comp.simps split_bang_comp.simps split_comp.simps)
     apply (auto simp add: weakening_comp.simps split_bang_comp.simps split_comp.simps)[1]
    apply (cases wa1; auto simp add: weakening_comp.simps split_bang_comp.simps split_comp.simps)
    done
next
  case (dobang t)
  then show ?thesis
    using assms
    apply -
    apply (erule split_bang_comp.cases)
      apply (fastforce simp add: weakening_comp.simps split_bang_comp.simps)
     apply (clarsimp simp add: weakening_comp.simps split_bang_comp.simps split_comp.simps, metis)
    apply (simp add: weakening_comp.simps split_bang_comp.simps)
    done
next
  case (bangdrop t k)
  then show ?thesis
    using assms
    by (auto simp add: weakening_comp.simps split_bang_comp.simps split_comp.simps)
qed


lemma weaken_and_split_bang:
  assumes "K , is \<turnstile> \<Gamma> \<leadsto>b \<Gamma>1 | \<Gamma>2"
    and "K \<turnstile> \<Gamma>1 \<leadsto>w w\<Gamma>1"
    and "K \<turnstile> \<Gamma>2 \<leadsto>w w\<Gamma>2"
  shows "\<exists>w\<Gamma> is'. is' \<subseteq> is \<and> (\<forall>i\<in>is'. \<Gamma> ! i = w\<Gamma> ! i) \<and> (K \<turnstile> \<Gamma> \<leadsto>w w\<Gamma>) \<and> (K , is' \<turnstile> w\<Gamma> \<leadsto>b w\<Gamma>1 | w\<Gamma>2)"
  using assms
proof (induct arbitrary: w\<Gamma>1 w\<Gamma>2 rule: split_bang.inducts)
  case (split_bang_cons _ isa K \<Gamma>' \<Gamma>1' \<Gamma>2' a a1 a2)

  obtain w\<Gamma>1' w\<Gamma>2' wa1 wa2
    where ctx_simps:
      "w\<Gamma>1 = wa1 # w\<Gamma>1'"
      "w\<Gamma>2 = wa2 # w\<Gamma>2'"
    using split_bang_cons.prems
    by (fastforce simp add: list_all2_Cons1 weakening_def)
  then have subweakenings:
    "weakening_comp K a1 wa1"
    "weakening_comp K a2 wa2"
    "K \<turnstile> \<Gamma>1' \<leadsto>w w\<Gamma>1'"
    "K \<turnstile> \<Gamma>2' \<leadsto>w w\<Gamma>2'"
    using split_bang_cons.prems weakening_nth
    by (fastforce simp add: weakening_def)+

  obtain w\<Gamma>' isb
    where IHresults:
      "isb \<subseteq> pred ` Set.remove 0 isa"
      "K \<turnstile> \<Gamma>' \<leadsto>w w\<Gamma>'"
      "K , isb \<turnstile> w\<Gamma>' \<leadsto>b w\<Gamma>1' | w\<Gamma>2'"
      "(\<forall>i\<in>isb. \<Gamma>' ! i = w\<Gamma>' ! i)"
    using split_bang_cons.hyps subweakenings by meson

  obtain wa dobang'
    where weaken_split_bang_step:
      "dobang' \<longrightarrow> 0 \<in> isa \<and> (\<exists>t. a = Some t) \<and> wa = a"
      "weakening_comp K a wa"
      "K , dobang' \<turnstile> wa \<leadsto>b wa1 \<parallel> wa2"
    using split_bang_cons.hyps subweakenings weaken_and_split_bang_comp
    by metis

  have
    "K \<turnstile> a # \<Gamma>' \<leadsto>w wa # w\<Gamma>'"
    using weaken_split_bang_step IHresults
    by (simp add: weakening_def)+
  moreover have "K , (if dobang' then insert 0 (Suc ` isb) else Suc ` isb) \<turnstile> wa # w\<Gamma>' \<leadsto>b wa1 # w\<Gamma>1' | wa2 # w\<Gamma>2'"
    using IHresults weaken_split_bang_step
    by (fastforce intro: split_bang.intros simp add: remove_def zero_notin_Suc_image set_pred_left_inverse_suc)
  moreover have
    "(if dobang' then insert 0 (Suc ` isb) else Suc ` isb) \<subseteq> isa"
    "\<forall>i\<in>(if dobang' then insert 0 (Suc ` isb) else Suc ` isb). (a # \<Gamma>') ! i = (wa # w\<Gamma>') ! i"
    using weaken_split_bang_step IHresults pred_right_inverse_Suc_for_nonzero
    by auto
  ultimately show ?case
    using ctx_simps by blast
qed (force simp add: split_bang.split_bang_empty weakening_def)


section {* Lemmas about the Type-system *}

lemma typing_to_kinding :
shows "\<Xi>, K, \<Gamma> \<turnstile>  e  : t  \<Longrightarrow> K \<turnstile>  t  wellformed"
and   "\<Xi>, K, \<Gamma> \<turnstile>* es : ts \<Longrightarrow> K \<turnstile>* ts wellformed"
proof (induct rule: typing_typing_all.inducts)
     case typing_var    then show ?case by (fastforce dest: weakening_preservation_some weakening_nth
                                                      simp: empty_length
                                                      elim: weakening_comp.cases)
next case typing_fun    then show ?case by (fastforce intro: kinding_kinding_all_kinding_record.intros
                                                             substitutivity)
next case typing_afun   then show ?case by (fastforce intro: kinding_kinding_all_kinding_record.intros
                                                             substitutivity)
next case typing_con    then show ?case by (fastforce simp add: kinding_all_set
                                                      intro!: kinding_kinding_all_kinding_record.intros)
next case typing_esac   then show ?case by (fastforce dest: filtered_member
                                                      elim: kinding.cases
                                                      simp add: kinding_all_set)
next case typing_member then show ?case by (fastforce intro: kinding_record_wellformed_nth)
next case typing_struct then show ?case by ( clarsimp
                                           , intro exI kind_trec kinding_all_record
                                           , simp_all add: kind_top map_fst_zip )
next case typing_take   then show ?case by (simp)
next case typing_put    then show ?case by (fastforce 
                                            simp add: map_update
                                            intro: kinding_kinding_all_kinding_record.intros
                                                   distinct_list_update kinding_record_update)
qed (auto intro: supersumption kinding_kinding_all_kinding_record.intros)

lemma upcast_valid_cast_to :
assumes "upcast_valid \<tau> \<tau>'"
    and "lit_type l = Num \<tau>"
obtains x where "cast_to \<tau>' l = Some x"
            and "lit_type x = Num \<tau>'"
using assms by (cases l, auto elim: upcast_valid.elims)

lemma bang_type_repr [simp]:
  shows "[] \<turnstile> t :\<kappa> k \<Longrightarrow> (type_repr (bang t) = type_repr t)"
    and "[] \<turnstile>* ts :\<kappa> k \<Longrightarrow> (map (type_repr \<circ> bang) ts) = map (type_repr) ts "
    and "[] \<turnstile>* fs :\<kappa>r k \<Longrightarrow> (map (type_repr \<circ>  bang \<circ> fst \<circ> snd) fs) = map (type_repr \<circ> fst \<circ> snd) fs"
    apply (induct "[] :: kind list"  t k
      and "[] :: kind list" ts k
      and "[] :: kind list" fs k
      rule: kinding_kinding_all_kinding_record.inducts)
               apply auto
   apply (case_tac s rule: sigil_cases, fastforce+)+
  done



subsection {* Specialisation *}

lemma specialisation:
assumes well_kinded: "list_all2 (kinding K') \<delta> K"
shows "\<Xi> , K , \<Gamma> \<turnstile>  e  : \<tau>  \<Longrightarrow> \<Xi> , K' , instantiate_ctx \<delta> \<Gamma> \<turnstile> specialise \<delta> e : instantiate \<delta> \<tau> "
and   "\<Xi> , K , \<Gamma> \<turnstile>* es : \<tau>s \<Longrightarrow> \<Xi> , K' , instantiate_ctx \<delta> \<Gamma> \<turnstile>* map (specialise \<delta>) es : map (instantiate \<delta>) \<tau>s"
  using assms
proof (induct rule: typing_typing_all.inducts)
  have f1: "(\<lambda>(c, p). (c, case p of (t, b) \<Rightarrow> (instantiate \<delta> t, b))) = (\<lambda>(c, t, b). (c, instantiate \<delta> t, b))"
    by force

  case (typing_case K \<Gamma> \<Gamma>1 \<Gamma>2 \<Xi> x ts tag t a u b)
  then have "\<Xi>, K', instantiate_ctx \<delta> \<Gamma> \<turnstile> Case (specialise \<delta> x) tag (specialise \<delta> a) (specialise \<delta> b) : instantiate \<delta> u"
  proof (intro typing_typing_all.typing_case)
    have "\<Xi>, K', instantiate_ctx \<delta> (Some (TSum (tagged_list_update tag (t, True) ts)) # \<Gamma>2) \<turnstile> specialise \<delta> b : instantiate \<delta> u"
      using typing_case.hyps(8) typing_case.prems by blast
    moreover have "(map (\<lambda>(c, t, b). (c, instantiate \<delta> t, b)) (tagged_list_update tag (t, True) ts)) = (tagged_list_update tag (instantiate \<delta> t, True) (map (\<lambda>(c, t, b). (c, instantiate \<delta> t, b)) ts))"
      using case_prod_conv f1 tagged_list_update_map_over1[where f = id and g = "\<lambda>_ (t,b). (instantiate \<delta> t, b)", simplified]
      by metis
    ultimately show "\<Xi>, K', Some (TSum (tagged_list_update tag (instantiate \<delta> t, True) (map (\<lambda>(c, t, b). (c, instantiate \<delta> t, b)) ts))) # instantiate_ctx \<delta> \<Gamma>2 \<turnstile> specialise \<delta> b : instantiate \<delta> u"
      by clarsimp
  qed (force intro: instantiate_ctx_split)+
  then show ?case by simp
next case (typing_afun \<Xi> f ks t u K ts ks)
  then also have "instantiate \<delta> (instantiate ts t) = instantiate (map (instantiate \<delta>) ts) t"
    and  "instantiate \<delta> (instantiate ts u) = instantiate (map (instantiate \<delta>) ts) u"
    by (force dest: list_all2_lengthD intro: instantiate_instantiate)+
  ultimately show ?case by (auto intro!: list_all2_substitutivity
        typing_typing_all.typing_afun [simplified]
        instantiate_ctx_consumed)
next case (typing_fun \<Xi> K t f u \<Gamma> ks ts)
  then also have "instantiate \<delta> (instantiate ts t) = instantiate (map (instantiate \<delta>) ts) t"
    and  "instantiate \<delta> (instantiate ts u) = instantiate (map (instantiate \<delta>) ts) u"
    by (force dest: list_all2_lengthD intro: instantiate_instantiate dest!: typing_to_kinding)+
  ultimately show ?case by (auto intro!: list_all2_substitutivity
        typing_typing_all.typing_fun [simplified]
        instantiate_ctx_consumed)
next case (typing_con \<Xi> K \<Gamma> x t tag ts ts')
  show ?case
    using typing_con
  proof (simp, intro typing_typing_all.intros)
    show "K' \<turnstile>* map (fst \<circ> snd) (map (\<lambda>(c, t, b). (c, instantiate \<delta> t, b)) ts) wellformed"
      apply (simp add: kinding_all_set)
      apply (metis (no_types, lifting) typing_con.hyps(4) typing_con.prems comp_apply
              kinding_all_set list.set_map rev_image_eqI substitutivity(2) type_wellformed_all_def)
      done
  next
    show "map (fst \<circ> snd) (map (\<lambda>(c, t, b). (c, instantiate \<delta> t, b)) ts) = map (fst \<circ> snd) (map (\<lambda>(c, t, b). (c, instantiate \<delta> t, b)) ts')"
      using map_fst3_app2 map_map typing_con.hyps by metis
  next
    show "list_all2 (\<lambda>x y. snd (snd y) \<longrightarrow> snd (snd x)) (map (\<lambda>(c, t, b). (c, instantiate \<delta> t, b)) ts) (map (\<lambda>(c, t, b). (c, instantiate \<delta> t, b)) ts')"
      by (simp add: list_all2_map1 list_all2_map2 case_prod_beta' typing_con.hyps(8))
  qed force+
next
  case (typing_esac \<Xi> K \<Gamma> x ts uu t)
  then show ?case
    by (force intro!: typing_typing_all.typing_esac
                simp: filter_map_map_filter_thd3_app2
                      typing_esac.hyps(3)[symmetric])+
qed (force intro!: typing_struct_instantiate
                   typing_typing_all.intros
           dest:   substitutivity
                   instantiate_ctx_split
                   instantiate_ctx_split_bang
                   instantiate_ctx_weaken
                   instantiate_ctx_consumed
           simp:   instantiate_ctx_def [where \<Gamma> = "[]", simplified]
                   map_update
           split:  prod.splits)+


fun expr_size :: "'f expr \<Rightarrow> nat" where
  "expr_size (Let a b) = Suc ((expr_size a) + (expr_size b))"
| "expr_size (LetBang vs a b) = Suc ((expr_size a) + (expr_size b))"
| "expr_size (Fun f ts) = Suc (expr_size f)"
| "expr_size (Unit) = 0"
| "expr_size (Member x f) = Suc (expr_size x)"
| "expr_size (Cast t x) = Suc (expr_size x)"
| "expr_size (Con c x ts) = Suc (expr_size ts)"
| "expr_size (App a b) = Suc ((expr_size a) + (expr_size b))"
| "expr_size (Prim p as) = Suc (sum_list (map expr_size as))"
| "expr_size (Var v) = 0"
| "expr_size (AFun v va) = 0"
| "expr_size (Struct v va) = Suc (sum_list (map expr_size va))"
| "expr_size (Lit v) = 0"
| "expr_size (Tuple v va) = Suc ((expr_size v) + (expr_size va))"
| "expr_size (Put v va vb) = Suc ((expr_size v) + (expr_size vb))"
| "expr_size (Esac x) = Suc (expr_size x)"
| "expr_size (If x a b) = Suc ((expr_size x) + (expr_size a) + (expr_size b))"
| "expr_size (Split x y) = Suc ((expr_size x) + (expr_size y))"
| "expr_size (Case x v a b) = Suc ((expr_size x) + (expr_size a) + (expr_size b))"
| "expr_size (Take x f y) = Suc ((expr_size x) + (expr_size y))"

lemma specialise_size [simp]:
  shows "expr_size (specialise \<tau>s x) = expr_size x"
proof -
have "\<forall> as . (\<forall> x. x \<in> set as \<longrightarrow> expr_size (specialise \<tau>s x) = expr_size x) \<longrightarrow>
  sum_list (map (expr_size \<circ> specialise \<tau>s) as) = sum_list (map expr_size as)"
by (rule allI, induct_tac as, simp+)
then show ?thesis by (induct x rule: expr_size.induct, auto)
qed

end
