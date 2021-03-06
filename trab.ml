(*trabalhinho de semântica 2017/2*)
(*Não creio que se faz comentário assim*)

(*
Isadora Oliveira 
Jonathan Martins
Leonardo Wellausen

*)

(*Sintaxe Abstrata:*)
type op = Sum
	|Sub
	|Mult
	|Great
	|GreatEq
	|Eq
	|Diff
	|LessEq
	|Less;;

type typ = TInt 
	| TTmB 
	| TFn of typ * typ;;

type ident = string;;

type term = TmN of int 
	| TmB of bool
	| TmEopE of term * op * term
	| TmIf of term * term * term
	| TmX of ident
	| TmEE of term * term
	| TmFn of ident * typ * term
	| TmLet of ident * typ * term * term
	| TmLet_rec of ident * (typ * typ) * (ident * typ * term) * term;;
	

(*exceptions*)
exception Identifier_Not_Found
exception Now_its_Exhaustive
exception Type_Error
exception Empty_Stack

(*Big Step Eval :*)	
type value = N of int
	| B of bool
	| Clsr of ident*term*env
	| RecClsr of ident*ident*term*env
	and env = (ident*value) list;;  (*and necessário porque declaração*)

(*funçãozinha auxiliar que será usada em BS-LET e BS-LETREC BS-APP e outra para o sistemas de tipos*)
let rec insertEnv identifier ident_value envir : env = match envir with
	| [] -> [(identifier, ident_value)]
	| hd::tl -> List.append [(identifier, ident_value)] envir 
	

let rec bs_eval environment e : value = match e with
	
	(*BS-TmN*)
	TmN(num) -> N(num)
	
	(*BS-TmB*)
	|TmB(boool) -> B(boool)
	
	(*BS-ID*)
	(*TESTAR!!!!!*)
	|TmX(x) -> 
		let rec findValue identifier envir : value = match envir with 
			[] -> raise Identifier_Not_Found
			| (this_ident, this_val)::term_rest ->
				if(this_ident = identifier)
				then this_val
				else findValue identifier term_rest in
		(findValue x environment)
	
	(*BS-IFTR*)
	|TmIf(e1, e2, e3) when ((bs_eval environment e1) = B(true)) -> bs_eval environment e2
	
	(*BS-IFFLS*)
	|TmIf(e1, e2, e3) when ((bs_eval environment e1) = B(false)) -> bs_eval environment e3
	
	(*BS-FN*)
	|TmFn(x, this_type, this_term) -> Clsr(x, this_term, environment)
	
	(*BS-LET*)
	|TmLet(x, this_type, e1, e2) ->
		let this_term = bs_eval environment e1 in
		(bs_eval (insertEnv x this_term environment) e2)
	
	(*BS-LETREC*)
	|TmLet_rec(f, (typeI, typeO), (x, typeX, e1), e2) ->
		let this_term = bs_eval environment (TmFn(x, typeX, e1)) in
		(match this_term with
			| Clsr(x_term, func_term, env_term) -> bs_eval (insertEnv f (RecClsr(f, x_term, func_term, environment)) env_term) e2 
			| _ -> raise Now_its_Exhaustive (*killing warnings*)
		)

	(*BS-APP*)
	(*
	| TmEE(e1, e2) ->
		let term_e1 = bs_eval environment e1 in
		let term_e2 = bs_eval environment e2 in
		(match term_e1, term_e2 with
			Clsr(x, e1_term, e1_env), val_e2 -> bs_eval (insertEnv x val_e2 e1_env) e1_term
			| _ -> raise Now_its_Exhaustive (*killing warnings*)
		)
	*)

	(*BS_APP +++ BS-APPREC  juntas porque usam o mesmo pattern matching*)
	| TmEE(e1, e2) ->
		let term_e1 = bs_eval environment e1 in
		let term_e2 = bs_eval environment e2 in
		(match term_e1, term_e2 with
			Clsr(x, e1_term, e1_env), val_e2 -> bs_eval (insertEnv x val_e2 e1_env) e1_term
			|RecClsr(f, x, e1_term, e1_env), val_e2 -> bs_eval (insertEnv f (RecClsr(f, x, e1_term, e1_env)) (insertEnv x val_e2 e1_env)) e1_term
			| _ -> raise Now_its_Exhaustive (*killing warnings*)
		)

	(*BS-OP    não está no resumo-l1 mas parece necessário*)
	|TmEopE(e1, op, e2) ->
		let term_e1 = bs_eval environment e1 in
		let term_e2 = bs_eval environment e2 in
		(match term_e1, op, term_e2 with
			N(v1), Sum, N(v2) -> N(v1 + v2)
			|N(v1), Sub, N(v2) -> N(v1 - v2)
			|N(v1), Mult, N(v2) -> N(v1 * v2)
			|N(v1), Great, N(v2) -> B(v1 > v2)
			|N(v1), GreatEq, N(v2) -> B(v1 >= v2)
			|N(v1), Eq, N(v2) -> B(v1 = v2)
			|N(v1), Diff, N(v2) -> B(v1 <> v2)
			|N(v1), LessEq, N(v2) -> B(v1 <= v2)
			|N(v1), Less, N(v2) -> B(v1 < v2)
			|B(v1), Eq, B(v2) -> B(v1 = v2)
			|B(v1), Diff, B(v2) -> B(v1 <> v2)
			
			| _ -> raise Now_its_Exhaustive (*killing warnings*)
		)
		
	| _ -> raise Now_its_Exhaustive (*killing warnings*);;


(*type system*)
type type_env = (ident * typ) list;;

(*aux para tipos que necessitam atualizar o env*)
let rec insertTypeEnv identifier ident_type envir : type_env = match envir with
	| [] -> [(identifier, ident_type)]
	| hd::tl -> List.append [(identifier, ident_type)] envir

let rec type_infer environment e : typ = match e with
	
	(*T-INT*)
	TmN(n) -> TInt
	
	(*T-TmB*)
	| TmB(b) -> TTmB
	
	(*T-OP todos*)
	|TmEopE(e1, op, e2) ->
		let type_e1 = type_infer environment e1 in
		let type_e2 = type_infer environment e2 in
		(match type_e1, op, type_e2 with
			TInt, Sum, TInt -> TInt
			|TInt, Sub, TInt -> TInt
			|TInt, Mult, TInt -> TInt
			|TInt, Great, TInt -> TTmB
			|TInt, GreatEq, TInt -> TTmB
			|TInt, Eq, TInt -> TTmB
			|TInt, Diff, TInt -> TTmB
			|TInt, LessEq, TInt -> TTmB
			|TInt, Less, TInt -> TTmB
			|TTmB, Eq, TTmB -> TTmB
			|TTmB, Diff, TTmB -> TTmB
			
			| _ -> raise Now_its_Exhaustive (*killing warnings*)
		)
	
	(*T-IF*)
	|TmIf(e1, e2, e3) ->
		let type_e1 = type_infer environment e1 in
		let type_e2 = type_infer environment e2 in
		let type_e3 = type_infer environment e3 in
		(match type_e1, type_e2, type_e3 with
			TTmB, TInt, TInt -> TInt
			|TTmB, TTmB, TTmB -> TTmB
			|TTmB, TFn(typeI,typeO), TFn(typeI2,typeO2) when(typeI = typeI2 && typeO = typeO2) -> TFn(typeI,typeO)
	
			| _ -> raise Now_its_Exhaustive (*killing warnings*)
		)

	(*T-VAR  testar too*)
	|TmX(x) -> 
		let rec findType identifier envir : typ = match envir with 
			[] -> raise Identifier_Not_Found
			| (this_ident, this_type)::term_rest ->
				if(this_ident = identifier)
				then this_type
				else findType identifier term_rest in
		(findType x environment)
		
	(*T_FUN*)
	|TmFn(x, x_type, f_term) -> TFn(x_type, (type_infer (insertTypeEnv x x_type environment) f_term))
	
	(*T-APP*)
	|TmEE(e1, e2) ->
		let type_e1 = type_infer environment e1 in
		let type_e2 = type_infer environment e2 in
		(match type_e1, type_e2 with
			TFn(e1_typeI, e1_typeO), e2_type when(e1_typeI = e2_type) -> e1_typeO
			| _ -> raise Now_its_Exhaustive (*killing warnings*)
		)
		
	(*T-LET*)
	|TmLet(x, type_x, e1, e2) -> type_infer (insertTypeEnv x type_x environment) e2
		
	(*T-LETREC*)
	|TmLet_rec(f, (typeI, typeO), (x, type_x, e1), e2) -> 
		let env_with_x = insertTypeEnv x type_x environment in
		let f_type = TFn(typeI, typeO) in
		(*let env_with_f = insertTypeEnv f TFn(typeI, typeO) env_with_x in*)
		let env_with_f = insertTypeEnv f f_type env_with_x in
		let type_e1 = type_infer env_with_f e1 in
		let type_e2 = type_infer (insertTypeEnv f f_type environment) e2 in
		(if type_e1 = typeO && typeI = type_x
		then type_e2
		else raise Type_Error
		);;



	
(*SSM2 compilação*)
type instruction = INT of int |TmB of bool
	|POP | COPY
	|ADD | INV | MULT
	|EQ | GT | LS | EQLS | EQGT | DIFF
	|AND | NOT
	|JUMP of int | JMPIFTRUE of int
	|VAR of ident
	| FUN of ident * code
	| RFUN of ident * ident * code
	|APPLY
and code = instruction list ;; (*de novo, and porque as definições são dependentes*)

type storable_value = SvINT of int
	|SvTmB of bool
	|SvCLOS of ssm2_env * ident * code
	|SvRCLOS of ssm2_env * ident * ident * code
and stack = storable_value list
and ssm2_env = (ident * storable_value) list
and dump = (code * stack * ssm2_env) list;;

type state = State of code * stack * ssm2_env * dump;;

(*semântica ssm2*)

(*função aux para dividir a lista code. RERTIRADA DO STACK OVERFLOW:
https://stackoverflow.com/questions/31616117/splitting-a-list-using-an-index
*)

let rec split_at1 n l =
	if n = 0 then ([], l) else
	match l with
	| [] -> ([], [])    (*or raise an exception, as you wish*)
	| h :: t -> let (l1, l2) = split_at1 (n-1) t in (h :: l1, l2);;
	
	
(*AQUELA auxiliar pra aumentar o ambiente*)
let rec insertSSM2Env identifier sv envir : ssm2_env = match envir with
	| [] -> [(identifier, sv)]
	| hd::tl -> List.append [(identifier, sv)] envir


let rec ssm2_eval cod stck env dp : state = match cod with

	(*as regras não têm nomes :( *)
	(* regra do int*)
	INT(n)::tl -> ssm2_eval tl (List.append [SvINT(n)] stck) env dp
	
	(*regra do TmB*)
	|TmB(b)::tl -> ssm2_eval tl (List.append [SvTmB(b)] stck) env dp
	
	(*regra do pop*)
	|POP::tl -> (match stck with
					[] -> raise Empty_Stack
					|hd::tls -> ssm2_eval tl tls env dp
				)
				
	(*regra do copy*)
	|COPY::tl -> (match stck with
					[] -> raise Empty_Stack
					|hd::tls -> ssm2_eval tl (List.append [hd] stck) env dp
				)
				
	(*regra do add*)
	|ADD::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvINT(n1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvINT(n2)::tltls -> ssm2_eval tl (List.append [SvINT(n1 + n2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)
					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)
	(*MULT*)
	|MULT::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvINT(n1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvINT(n2)::tltls -> ssm2_eval tl (List.append [SvINT(n1 * n2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)
					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)
				
	
	(*regra do inv*)
	|INV::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvINT(n)::tls -> ssm2_eval tl (List.append [SvINT(-1 * n)] tls) env dp
				
					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)
				
	(*regra do eq*)
	|EQ::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvINT(n1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvINT(n2)::tltls -> ssm2_eval tl (List.append [SvTmB(n1 = n2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)
					|SvTmB(n1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvTmB(n2)::tltls -> ssm2_eval tl (List.append [SvTmB(n1 = n2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)
					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)
	(*diff*)
	|DIFF::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvINT(n1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvINT(n2)::tltls -> ssm2_eval tl (List.append [SvTmB(n1 <> n2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)
					|SvTmB(n1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvTmB(n2)::tltls -> ssm2_eval tl (List.append [SvTmB(n1 <> n2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)
					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)

	(*regra do gt*)
	|GT::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvINT(n1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvINT(n2)::tltls -> ssm2_eval tl (List.append [SvTmB(n1 > n2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)

					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)
	(*less*)
	|LS::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvINT(n1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvINT(n2)::tltls -> ssm2_eval tl (List.append [SvTmB(n1 < n2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)

					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)
	(*equal less*)
	|EQLS::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvINT(n1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvINT(n2)::tltls -> ssm2_eval tl (List.append [SvTmB(n1 <= n2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)

					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)
	(*eq great*)
	|EQGT::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvINT(n1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvINT(n2)::tltls -> ssm2_eval tl (List.append [SvTmB(n1 >= n2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)

					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)
				
	(*regra do and*)
	|AND::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvTmB(b1)::tls -> (match tls with
											[] -> raise Empty_Stack
											|SvTmB(b2)::tltls -> ssm2_eval tl (List.append [SvTmB(b1 && b2)] tltls) env dp
										
											| _ -> raise Now_its_Exhaustive (*killing warnings*)
										)
					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)
				
	(*regra do not*)
	|NOT::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvTmB(b)::tls -> ssm2_eval tl (List.append [SvTmB(not b)] tls) env dp
				
					| _ -> raise Now_its_Exhaustive (*killing warnings*)
				)
				
	(*regra do jump*)
	|JUMP(n)::tl -> let (cod1, cod2) = split_at1 n tl in (ssm2_eval cod2 stck env dp)
	
	(*regra do jmpiftrue*)
	|JMPIFTRUE(n)::tl -> let (cod1, cod2) = split_at1 n tl in
						(match stck with
							[] -> raise Empty_Stack
							|SvTmB(b)::tls -> (if b then (ssm2_eval cod2 tls env dp) else (ssm2_eval tl tls env dp))
							
							| _ -> raise Now_its_Exhaustive (*killing warnings*)
						)
	
	(*regra do var*)
	|VAR(x)::tl -> 
		let rec findSValue identifier envir : storable_value = match envir with 
			[] -> raise Identifier_Not_Found
			| (this_ident, this_sval)::env_rest ->
				if(this_ident = identifier)
				then this_sval
				else findSValue identifier env_rest in
				(ssm2_eval tl (List.append [findSValue x env] stck) env dp)
	
	(*regra do fun*)
	|FUN(x, cod_f)::tl -> ssm2_eval tl (List.append [SvCLOS(env, x, cod_f)] stck) env dp
	
	(*regra da rfun*)
	|RFUN(f, x, cod_f)::tl -> ssm2_eval tl (List.append [SvRCLOS(env, f, x, cod_f)] stck) env dp
	
	(*regra do apply para clos e rclos*)
	|APPLY::tl -> (match stck with
					[] -> raise Empty_Stack
					|SvCLOS(env_c, x, cod_c)::tls -> 
						(match tls with
							[]-> raise Empty_Stack
							|hd::tltls -> ssm2_eval cod_c [] (insertSSM2Env x hd env_c) (List.append [(tl, tltls, env)] dp)
						)
					|SvRCLOS(env_c, f, x, cod_c)::tls ->
						(match tls with 
							[] -> raise Empty_Stack
							|hd::tltls -> ssm2_eval cod_c [] (insertSSM2Env f (SvRCLOS(env_c, f, x, cod_c)) (insertSSM2Env x hd env_c)) (List.append [(tl, tltls, env)] dp)
						)
					| _ -> raise Now_its_Exhaustive (*killing warnings*)
					)
					
	(*caso code seja vazio, checar o dumpzin*)
	|[] -> (match dp with
				[]-> State(cod, stck, env, dp) (*é isso mesmo? retornamos um state value?? teóricamente há um elemento na stack??? *)
				| (cod_d, stck_d, env_d)::tl -> ssm2_eval cod_d (List.append [(List.hd stck)] stck_d) env_d tl
			);;
			
			
(*agora dá pra compilar L1 pra ssm2? omg*)
let rec c (*acho que aquele desenho chiq é um c*)  term : code = match term with

	(*regra dos int*)
	TmN(n) -> [INT(n)]
	
	(*regra dos TmB*)
	|TmB(b) -> [TmB(b)]
	
	(*regra das op*)
	| TmEopE(e1, op, e2) ->
		let term_e1 = c  e1 in
		let term_e2 = c  e2 in
		(match op with
			Sum -> List.append term_e2 (List.append term_e1 [ADD])
			|Sub -> List.append (List.append term_e2 (List.append [INV] term_e1)) [ADD]			
			| Mult -> List.append term_e2 (List.append term_e1 [MULT])
			|Great -> List.append term_e2 (List.append term_e1 [GT])
			| GreatEq -> List.append term_e2 (List.append term_e1 [EQGT])
 			|Eq -> List.append term_e2 (List.append term_e1 [EQ])
			| Diff -> List.append term_e2 (List.append term_e1 [DIFF])
			| LessEq -> List.append term_e2 (List.append term_e1 [EQLS])
			| Less -> List.append term_e2 (List.append term_e1 [LS])
		)
		
	(*regra do if*)
	|TmIf(e1, e2, e3) ->
		let term_e1 = c  e1 in
		let term_e2 = c  e2 in	
		let term_e3 = c  e3 in
		(
		(*List.append (List.append (List.append term_e1 (List.append [JMPIFTRUE((List.length term_e3) +1)] term_e3)) [JUMP((List.length term_e2))]) term_e2*)
		List.append term_e1 (List.append [JMPIFTRUE((List.length term_e3) +1)] (List.append term_e3 (List.append [JUMP((List.length term_e2))] term_e2))) 
		)
	
	(*regra do var*)
	|TmX(x) -> [VAR(x)]
	
	(*regra da aplicação*)
	|TmEE(e1, e2) ->
		let term_e1 = c  e1 in
		let term_e2 = c  e2 in
		( List.append term_e2 (List.append term_e1 [APPLY]))
		
	(*regra do fun*)
	|TmFn(x, type_x, term_f) -> [FUN(x,  (c  term_f))]
	
	(*regra do let*)
	|TmLet(x, type_x, e1, e2) ->
		let term_e1 = c  e1 in
		let term_e2 = c  e2 in
		(List.append term_e1 (List.append [FUN(x, term_e2)] [APPLY]))
		
	(*Regra do let rec*)
	|TmLet_rec(f, (typeI, typeO), (x, type_x, e1), e2) -> 
		let term_e1 = c  e1 in
		let term_e2 = c  e2 in
		(List.append [RFUN(f, x, term_e1)] (List.append [FUN(f, term_e2)] [APPLY]))
		
	;;
	
	(***************TESTES******************)

	let environment : env = []

	let environmentSSM2 : ssm2_env = [];;
	let d : dump = [];;
	let st : stack = [];;

	let print_value s v : unit =
		(match v with 
			| N(n) -> Printf.printf "A avaliacao de %s resultou em %d\n" s n
			| B(b) -> Printf.printf "A avaliacao de %s resultou em  %B\n" s b
			| Clsr(var, exp, env) -> Printf.printf "A avaliacao de %s resultou em uma Clsr\n" s
			| RecClsr(f, var, exp, env) ->  Printf.printf "A avaliacao de %s resultou em uma RecClsr\n" s
		)
		

	let print_type s t : unit =
		(match t with 
			| TInt -> Printf.printf "O type infer de %s resultou em tipo TInt\n" s 
			| TTmB -> Printf.printf "O type infer de %s resultou em  tipo TBool\n" s
			| TFn(TInt, TInt) -> Printf.printf "O type infer de %s resultou em tipo TInt -> TInt\n" s 
			| TFn(TTmB, TTmB) -> Printf.printf "O type infer de %s resultou em tipo TBool -> TBool\n" s 
			| TFn(TInt, TTmB) -> Printf.printf "O type infer de %s resultou em tipo TInt -> TBool\n" s 
			| TFn(TTmB, TInt) -> Printf.printf "O type infer de %s resultou em tipo TBool -> TInt\n" s 
			| TFn(_,_) -> Printf.printf "O type infer de %s resultou em algum tipo TFn maluco\n" s 
		)



	let print_valueSSM2 s v : unit =
		(match v with 
			| SvINT(n) -> Printf.printf "A avaliacao de %s resultou em  %d\n\n\n\n\n" s n
			| SvTmB(b) -> Printf.printf "A avaliacao de %s resultou em  %B\n\n\n\n\n" s b
			| SvCLOS(var, exp, env) -> Printf.printf "A avaliacao de %s resultou em uma SvCLOS\n\n\n\n\n" s
			| SvRCLOS(f, var, exp, env) ->  Printf.printf "A avaliacao de %s resultou em uma SvRCLOS\n\n\n\n\n" s
		)
		
	let get_head a: storable_value =
			( match a with
				|State(cod, hd::tls, env, dp) -> hd
				| _ -> raise Now_its_Exhaustive
			);;


	
	Printf.printf "\n\n";;
	(*Primeiro é rodado o type_infer sobre a árvore, depois avaliacao L1, depois compilação L1 para ssm2*)
	(*teste sub*)
	let sub = TmEopE(TmN(10), Sub, TmN(5));;	
	print_type "sub" (type_infer [] sub);;	
	let testSub = bs_eval environment sub;;
	print_value "sub" testSub;;
	let subCode = c sub;;
	let subState = ssm2_eval subCode [] [] [];;
	let subValue = get_head subState;;
	print_valueSSM2 "sub SSM2" subValue;;


	
	(*teste sum*)
	let sum = TmEopE(TmN(10), Sum, TmN(5));;
	print_type "sum" (type_infer [] sum);;
	let testSum = bs_eval environment sum;;
	print_value "sum" testSum;;
	let sumCode = c sum;;
	let sumState = ssm2_eval sumCode [] [] [];;
	let sumValue = get_head sumState;;
	print_valueSSM2 "sum SSM2" sumValue;;
	
	
	(*teste mult*)
	let mult = TmEopE(TmN(10), Mult, TmN(5));;
	print_type "mult" (type_infer [] mult);;
	let testMult = bs_eval environment mult;;
	print_value "mult" testMult;;
	let multCode = c mult;;
	let multState = ssm2_eval multCode [] [] [];;
	let multValue = get_head multState;;
	print_valueSSM2 "mult SSM2" multValue;;

	
	(*teste less*)
	let less = TmEopE(TmN(10), Less, TmN(5));;
	print_type "less" (type_infer [] less);;
	let testLess = bs_eval environment less;;
	print_value "less" testLess;;
	let lessCode = c less;;
	let lessState = ssm2_eval lessCode [] [] [];;
	let lessValue = get_head lessState;;
	print_valueSSM2 "less SSM2" lessValue;;

	
	(*teste eqNum*)
	let eqNum = TmEopE(TmN(10), Eq, TmN(5));;
	print_type "eqNum" (type_infer [] eqNum);;
	let testEqNum = bs_eval environment eqNum;;
	print_value "eqNum" testEqNum;;
	let eqNumCode = c eqNum;;
	let eqNumState = ssm2_eval eqNumCode [] [] [];;
	let eqNumValue = get_head eqNumState;;
	print_valueSSM2 "eqNum SSM2" eqNumValue;;

	
	(*teste eqBool*)
	let eqBool = TmEopE(TmB(false), Eq, TmB(true));;
	print_type "eqBool" (type_infer [] eqBool);;
	let testEqBool = bs_eval environment eqBool;;
	print_value "eqBool" testEqBool;; 
	let eqBoolCode = c eqBool;;
	let eqBoolState = ssm2_eval eqBoolCode [] [] [];;
	let eqBoolValue = get_head eqBoolState;;
	print_valueSSM2 "eqBool SSM2" eqBoolValue;;
	
	
	
	(*teste great*)
	let great  = TmEopE(TmN(10), Great, TmN(5));;
	print_type "great" (type_infer [] great);;
	let testGreat = bs_eval environment great;;
	print_value "great" testGreat;;
	let greatCode = c great;;
	let greatState = ssm2_eval greatCode [] [] [];;
	let greatValue = get_head greatState;;
	print_valueSSM2 "great SSM2" greatValue;;
	
	
	
	(*teste diffNum*)
	let diffNum = TmEopE(TmN(10), Diff, TmN(5));;
	print_type "diffNum" (type_infer [] diffNum);;
	let testDiffNum = bs_eval environment diffNum;;
	print_value "diffNum" testDiffNum;;
	let diffNumCode = c diffNum;;
	let diffNumState = ssm2_eval diffNumCode [] [] [];;
	let diffNumValue = get_head diffNumState;;
	print_valueSSM2 "diffNum SSM2" diffNumValue;;

	
	
	
	(*teste diffBool*)
	let diffBool = TmEopE(TmB(false), Diff, TmB(true));;
	print_type "diffBool" (type_infer [] diffBool);;
	let testDiffBool = bs_eval environment diffBool;;
	print_value "diffBool" testDiffBool;; 
	let diffBoolCode = c diffBool;;
	let diffBoolState = ssm2_eval diffBoolCode [] [] [];;
	let diffBoolValue = get_head diffBoolState;;
	print_valueSSM2 "diffBool SSM2" diffBoolValue;;

	
	
	(*teste lessEq*)
	let lessEq = TmEopE(TmN(10), LessEq, TmN(5));;
	print_type "lessEq" (type_infer [] lessEq);;
	let testLessEq = bs_eval environment lessEq;;
	print_value "lessEq" testLessEq;;
	let lessEqCode = c lessEq;;
	let lessEqState = ssm2_eval lessEqCode [] [] [];;
	let lessEqValue = get_head lessEqState;;
	print_valueSSM2 "lessEq SSM2" lessEqValue;;

	
	
	(*teste greatEq*)
	let greatEq = TmEopE(TmN(10), GreatEq, TmN(5));;
	print_type "greatEq" (type_infer [] greatEq);;
	let testGreatEq = bs_eval environment greatEq;;
	print_value "greatEq" testGreatEq;;
	let greatEqCode = c greatEq;;
	let greatEqState = ssm2_eval greatEqCode [] [] [];;
	let greatEqValue = get_head greatEqState;;
	print_valueSSM2 "greatEq SSM2" greatEqValue;;

	
	
	(*teste ifTrue*)
	let ifTrue = TmIf(TmEopE(TmN(99), Diff, TmN(25)), TmB(true), TmB(false));;
	print_type "ifTrue" (type_infer [] ifTrue);;
	let testIfTrue = bs_eval environment ifTrue;;
	print_value "ifTrue" testIfTrue;;
	let ifTrueCode = c ifTrue;;
	let ifTrueState = ssm2_eval ifTrueCode [] [] [];;
	let ifTrueValue = get_head ifTrueState;;
	print_valueSSM2 "ifTrue SSM2" ifTrueValue;;

	
	
	(*ifFalse*)
	let ifFalse = TmIf(TmEopE(TmN(99), Diff, TmN(99)), TmB(true), TmB(false));;
	print_type "ifFalse" (type_infer [] ifFalse);;
	let testIfFalse = bs_eval environment ifFalse;;
	print_value "ifFalse" testIfFalse;;
	let ifFalseCode = c ifFalse;;
	let ifFalseState = ssm2_eval ifFalseCode [] [] [];;
	let ifFalseValue = get_head ifFalseState;;
	print_valueSSM2 "ifFalse SSM2" ifFalseValue;;

	

	(*teste fn*)
	let fn = TmFn("x", TInt, TmEopE(TmX("x"), Sub, TmN(1)));;
	print_type "fn" (type_infer [] fn);;
	let testFn = bs_eval environment fn;;
	print_value "fn" testFn;;
	let fnCode = c fn;;
	let fnState = ssm2_eval fnCode [] [] [];;
	let fnValue = get_head fnState;;
	print_valueSSM2 "fn SSM2" fnValue;;


	let x = TmX("x");;
	
	(*teste tEE*)
	let tEE = TmEE(TmFn("x", TInt, TmEopE(x, Sub, TmN(4))), TmN(5));;
	print_type "tEE" (type_infer [] tEE);;
	let testTEE = bs_eval environment tEE;;
	print_value "tEE" testTEE;;
	let tEECode = c tEE;;
	let tEEState = ssm2_eval tEECode [] [] [];;
	let tEEValue = get_head tEEState;;
	print_valueSSM2 "tEE SSM2" tEEValue;;


	
	(*teste let1*)
	let let1 = TmLet("x", TInt, TmN(2), TmEopE(TmX("x"), Sub, TmN(2)));;
	print_type "let1" (type_infer [] let1);;
	let testLet1 = bs_eval environment let1;;
	print_value "let1" testLet1;;
	let let1Code = c let1;;
	let let1State = ssm2_eval let1Code [] [] [];;
	let let1Value = get_head let1State;;
	print_valueSSM2 "let1 SSM2" let1Value;;

	
	
	
	(*teste let2*)
	let let2 = TmLet("x", TInt, TmN(2), TmLet("y", TInt, TmN(2), TmEopE(TmX("x"), Mult, TmX("y"))));;
	print_type "let2" (type_infer [] let2);;
	let testLet2 = bs_eval environment let2;;
	print_value "let2" testLet2;;
	let let2Code = c let2;;
	let let2State = ssm2_eval let2Code [] [] [];;
	let let2Value = get_head let2State;;
	print_valueSSM2 "let2 SSM2" let2Value;;


	
	
	
	(*teste let3*)
	let let3 = TmLet("x", TInt, TmN(23), TmIf(TmEopE(TmX("x"), Eq, TmN(23)), TmB(true), TmB(false)));;
	print_type "let3" (type_infer [] let3);;
	let testLet3 = bs_eval environment let3;;
	print_value "let3" testLet3;;
	let let3Code = c let3;;
	let let3State = ssm2_eval let3Code [] [] [];;
	let let3Value = get_head let3State;;
	print_valueSSM2 "let3 SSM2" let3Value;;

	
	
	
	(*teste letRec1*)
	let letRec1 = TmLet_rec("fat", (TInt, TInt), ("x", TInt,
							TmIf(TmEopE(TmX("x"), Eq, TmN(0)),
								TmN(1),
								TmEopE(TmX("x"), Mult, TmEE(TmX("fat"), TmEopE(TmX("x"), Sub, TmN(1))))
							)),
							TmEE(TmX("fat"), TmN(8))
						);;
	print_type "letRec1" (type_infer [] letRec1);;
	let testletRec1 = bs_eval environment letRec1;;
	print_value "letRec1" testletRec1;;
	let letRec1Code = c letRec1;;
	let letRec1State = ssm2_eval letRec1Code [] [] [];;
	let letRec1Value = get_head letRec1State;;
	print_valueSSM2 "letRec1 SSM2" letRec1Value;;

	
	
	
	(*teste letRec2*)
	let letRec2 = TmLet_rec("fib", (TInt, TInt), ("x", TInt,
							TmIf(TmEopE(TmX("x"), Less, TmN(2)),
								TmX("x"),
								TmEopE(TmEE(TmX("fib"), TmEopE(TmX("x"), Sub, TmN(1))), Sum, TmEE(TmX("fib"), TmEopE(TmX("x"), Sub, TmN(2))))
							)),
							TmEE(TmX("fib"), TmN(8))
						);;
	print_type "letRec2" (type_infer [] letRec2);;
	let testletRec2 = bs_eval environment letRec2;;
	print_value "letRec2" testletRec2;;
	let letRec2Code = c letRec2;;
	let letRec2State = ssm2_eval letRec2Code [] [] [];;
	let letRec2Value = get_head letRec2State;;
	print_valueSSM2 "letRec2 SSM2" letRec2Value;;
