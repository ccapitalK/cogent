--
-- Copyright 2019, Data61
-- Commonwealth Scientific and Industrial Research Organisation (CSIRO)
-- ABN 41 687 119 230.
--
-- This software may be distributed and modified according to the terms of
-- the GNU General Public License version 2. Note that NO WARRANTY is provided.
-- See "LICENSE_GPLv2.txt" for details.
--
-- @TAG(DATA61_GPL)
--

module Cogent.Quote where

import Cogent.Dargent.Surface ()
import Cogent.Parser
import Cogent.Surface ()
import Cogent.Util (thd3)

import Data.Data
import Language.Haskell.TH.Quote (QuasiQuoter(..))
import Language.Haskell.TH.Syntax (Q(..), Exp, liftData)
import Text.Parsec (runParser)

quasiquote :: (Data b) => Parser a String -> (a -> b) -> QuasiQuoter
quasiquote p f = QuasiQuoter 
                   { quoteExp  = parse p f
                   , quotePat  = notSupported "patterns"
                   , quoteType = notSupported "types"
                   , quoteDec  = notSupported "declarations"
                   }
  where notSupported s = error $ "Quasiquoting " ++ s ++ " is not supported."

parse :: (Data b) => Parser a String -> (a -> b) -> String -> Q Exp
parse p f s = case runParser p "" "" s of
                Left  e -> error $ "Parsing failed: " ++ show e
                Right x -> liftData $ f x

decl  = quasiquote toplevel' thd3
decls = quasiquote program (map thd3)
mty   = quasiquote monotype id

dexpr = quasiquote repExpr id
