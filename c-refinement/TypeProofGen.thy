(*
 * Copyright 2018, Data61
 * Commonwealth Scientific and Industrial Research Organisation (CSIRO)
 * ABN 41 687 119 230.
 *
 * This software may be distributed and modified according to the terms of
 * the BSD 2-Clause license. Note that NO WARRANTY is provided.
 * See "LICENSE_BSD2.txt" for details.
 *
 * @TAG(DATA61_BSD)
 *)

theory TypeProofGen imports
  "../cogent/isa/CogentHelper"
  "../cogent/isa/ProofTrace"
begin

(* Convert ttyping subproofs to standard typing subproofs. *)
lemma ttsplit_imp_split':
  "ttsplit k \<Gamma> splits xs \<Gamma>1 ys \<Gamma>2 \<Longrightarrow>
    k \<turnstile> snd \<Gamma> \<leadsto> drop (length xs) (snd \<Gamma>1) | drop (length ys) (snd \<Gamma>2)"
  by (fastforce dest: ttsplit_imp_split)


lemma ttsplit_inner_imp_split:
  assumes
    "ttsplit_inner K splits \<Gamma>b \<Gamma>1 \<Gamma>2"
    "list_all ((\<noteq>) (Some TSK_NS)) splits"
  shows
    "K \<turnstile> snd (TyTrSplit splits xs T1 ys T2, \<Gamma>b) \<leadsto>
      drop (length xs) (snd (T1, xs @ \<Gamma>1)) | drop (length ys) (snd (T2, ys @ \<Gamma>2))"
  using assms
  by (blast dest: ttsplitI ttsplit_imp_split')

lemma ttsplit_bang_imp_split_bang':
  "ttsplit_bang is splits k \<Gamma> xs \<Gamma>1 ys \<Gamma>2 \<Longrightarrow>
    split_bang k is (snd \<Gamma>) (drop (length xs) (snd \<Gamma>1)) (drop (length ys) (snd \<Gamma>2))"
  by (fastforce dest: ttsplit_bang_imp_split_bang)

(* Generate type system lemma buckets *)
ML {*

(* identify judgements related to typing *)
fun is_typing t = head_of t |>
  (fn h => is_const "TypeTrackingTyping.ttyping" h orelse
           is_const "TypeTrackingTyping.ttsplit" h orelse
           is_const "TypeTrackingTyping.ttsplit_bang" h orelse
           is_const "TypeTrackingTyping.ttsplit_inner" h orelse
           is_const "Cogent.typing" h orelse
           is_const "Cogent.split" h orelse
           is_const "Cogent.kinding" h);

(* remove consecutive duplicates *)
fun uniq cmp (x::y::xs) = (case cmp (x,y) of EQUAL => uniq cmp (x::xs)
                                           | _ => x::uniq cmp (y::xs))
  | uniq _ xs = xs

fun get_typing_tree ctxt f proof : thm tree list =
  let val abbrev_defs = Proof_Context.get_thms ctxt "abbreviated_type_defs"
                        handle ERROR _ => [];
      (* generate a simpset of all the definitions of the `f` function, type, and typetree *)
      val defs = maps (Proof_Context.get_thms ctxt)
                   (map (prefix f) ["_def", "_type_def", "_typetree_def"])
                 @ abbrev_defs;
  in extract_subproofs
       (* The typing goal for `f` *)
       (Syntax.read_term ctxt
         ("Trueprop (\<Xi>, fst " ^ f ^ "_type, (" ^ f ^ "_typetree, [Some (fst (snd " ^ f ^ "_type))])" ^
          "            T\<turnstile> " ^ f ^ " : snd (snd " ^ f ^ "_type))")
        |> Thm.cterm_of ctxt)
       (let val hinted_tacs = map (fn (tag, t) => (SOME tag, t ctxt)) proof
            val all_tacs = (NONE, asm_full_simp_tac (ctxt addsimps defs) 1) :: hinted_tacs
          in all_tacs end)
       is_typing ctxt
     |> (fn r => case r of
            Right tr => tr
          | Left err =>
            let
              val _ = log_error ("get_typing_tree failed for function " ^ f)
              val _ = log_error (@{make_string} (get_failing_goal err))
              val _ = @{print error} (get_failing_goal err)
              (* val _ = @{print error} err *)
            in
              error ("get_typing_tree failed for function " ^ f)
            end)
  end

fun simplify_thm ctxt thm =
  Conv.fconv_rule (Simplifier.rewrite ctxt) thm

fun cleanup_typing_tree_thm ctxt thm = Goal.finish ctxt thm
  |> (fn t =>
       (
        (t RS @{thm ttsplit_imp_split'}) handle THM _ =>
        (t RS @{thm ttsplit_inner_imp_split}) handle THM _ =>
        (t RS @{thm ttsplit_bang_imp_split_bang'}) handle THM _ =>
        (t RS @{thm ttyping_imp_typing}) handle THM _ =>
        t
       )
    |> simplify_thm ctxt)
  |> Thm.varifyT_global

fun get_final_typing_tree ctxt f proof =
  get_typing_tree ctxt f proof
  |> map (tree_map (cleanup_typing_tree_thm ctxt))

(* covert a typing tree to a list of typing theorems *)
val typing_tree_to_bucket =
  map flatten_tree
    #> List.concat
    #> sort_distinct Thm.thm_ord

fun get_typing_bucket ctxt f proof =
  get_typing_tree ctxt f proof
    |> map flatten_tree
    |> List.concat
    |> map (cleanup_typing_tree_thm ctxt)
    |> sort Thm.thm_ord
    |> uniq Thm.thm_ord

type details = (thm list * thm tree list * thm list)


fun get_all_typing_details ctxt name script : details = let
    val _ = (@{print tracing} ("typetac: start " ^ name))
    val _ = (log_info ("typetac: start " ^ name))
    val time = Timing.start ()
    val script_tree = (case parse_treesteps script of
        SOME tree => tree
      | NONE => raise ERROR ("failed to parse script tree"))
    (* val time_res = Timing.result time *)
    (* val _ = (@{print tracing} "phase: parse script"; @{print tracing} time_res) *)
    (* val _ = (log_info "phase: parse script"; log_info (@{make_string} time_res)) *)

    (* val time = Timing.start () *)
    val tacs = TTyping_Tactics.mk_ttsplit_tacs_final name
        @{term "[] :: kind env"} ctxt script_tree
    val tacs' = map (fn (tac, f) => (tac, fn ctxt => f ctxt 1)) tacs
    (* val time_res = Timing.result time *)
    (* val _ = (@{print tracing} "phase: tac gen"; @{print tracing} time_res) *)
    (* val _ = (log_info "phase: tac gen"; log_info (@{make_string} time_res)) *)

    (* val time = Timing.start () *)
    val orig_typing_tree = get_typing_tree ctxt name tacs'
    (* val time_res = Timing.result time *)
    (* val _ = (@{print tracing} "phase: type-tree solve " ^ name; @{print tracing} time_res) *)
    (* val _ = (log_info ("phase: type-tree solve " ^ name); log_info (@{make_string} time_res)) *)

    (* val time = Timing.start () *)
    val typecorrect_thms = map (Goal.finish ctxt) (map tree_value orig_typing_tree)
      |> map (simplify ctxt #> Thm.varifyT_global)
    val typing_tree = map (tree_map (cleanup_typing_tree_thm ctxt)) orig_typing_tree
    (* val time_res = Timing.result time *)
    (* val _ = (@{print tracing} "phase: cleanup thm tree"; @{print tracing} time_res) *)
    (* val _ = (log_info "phase: cleanup thm tree"; log_info (@{make_string} time_res)) *)

    (* val time = Timing.start () *)
    val bucket = typing_tree_to_bucket typing_tree
    val time_res = Timing.result time
    val _ = (@{print tracing} ("typetac: finish " ^ name); @{print tracing} time_res)
    val _ = (log_info ("typetac: finish " ^ name); log_info (@{make_string} time_res))
    (* val _ = (@{print tracing} "phase: make thm bucket"; @{print tracing} time_res) *)
    (* val _ = (log_info "phase: make thm bucket"; log_info (@{make_string} time_res)) *)
  in (typecorrect_thms, typing_tree, bucket) end

fun get_all_typing_details_future ctxt name script
    = Future.fork (fn () => get_all_typing_details ctxt name script)

fun resolve_future_typecorrect ctxt details
    = resolve_tac ctxt (#1 (Future.join details : details)) 1
*}

end
