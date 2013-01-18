
{-# OPTIONS -fno-warn-tabs #-}
-- The above warning supression flag is a temporary kludge.
-- While working on this module you are encouraged to remove it and
-- detab the module (please do the detabbing in a separate patch). See
--     http://hackage.haskell.org/trac/ghc/wiki/Commentary/CodingStyle#TabsvsSpaces
-- for details

module SPARC.CodeGen.Base (
	InstrBlock,
	CondCode(..),
	ChildCode64(..),
	Amode(..),

	Register(..),
	setSizeOfRegister,
	
	getRegisterReg,
	mangleIndexTree
)

where

import SPARC.Instr
import SPARC.Cond
import SPARC.AddrMode
import SPARC.Regs
import Size
import Reg

import CodeGen.Platform
import DynFlags
import Cmm
import Platform

import Outputable
import OrdList

--------------------------------------------------------------------------------
-- | 'InstrBlock's are the insn sequences generated by the insn selectors.
-- 	They are really trees of insns to facilitate fast appending, where a
-- 	left-to-right traversal yields the insns in the correct	order.
--
type InstrBlock 
	= OrdList Instr


-- | Condition codes passed up the tree.
--
data CondCode 	
	= CondCode Bool Cond InstrBlock


-- | a.k.a "Register64"
--	Reg is the lower 32-bit temporary which contains the result. 
--	Use getHiVRegFromLo to find the other VRegUnique.  
--
--	Rules of this simplified insn selection game are therefore that
--	the returned Reg may be modified
--
data ChildCode64 	
   = ChildCode64 
        InstrBlock
        Reg	 	


-- | Holds code that references a memory address.
data Amode 
	= Amode 
		-- the AddrMode we can use in the instruction 
		--	that does the real load\/store.
		AddrMode 	

		-- other setup code we have to run first before we can use the
		--	above AddrMode.
		InstrBlock	



--------------------------------------------------------------------------------
-- | Code to produce a result into a register.
--	If the result must go in a specific register, it comes out as Fixed.
--	Otherwise, the parent can decide which register to put it in.
--
data Register
	= Fixed	Size Reg InstrBlock
	| Any	Size (Reg -> InstrBlock)


-- | Change the size field in a Register.
setSizeOfRegister
	:: Register -> Size -> Register

setSizeOfRegister reg size
 = case reg of
 	Fixed _ reg code 	-> Fixed size reg code
	Any _ codefn     	-> Any   size codefn


--------------------------------------------------------------------------------
-- | Grab the Reg for a CmmReg
getRegisterReg :: Platform -> CmmReg -> Reg

getRegisterReg _ (CmmLocal (LocalReg u pk))
  	= RegVirtual $ mkVirtualReg u (cmmTypeSize pk)

getRegisterReg platform (CmmGlobal mid)
  = case globalRegMaybe platform mid of
        Just reg -> RegReal reg
        Nothing  -> pprPanic
                        "SPARC.CodeGen.Base.getRegisterReg: global is in memory"
                        (ppr $ CmmGlobal mid)


-- Expand CmmRegOff.  ToDo: should we do it this way around, or convert
-- CmmExprs into CmmRegOff?
mangleIndexTree :: DynFlags -> CmmExpr -> CmmExpr

mangleIndexTree dflags (CmmRegOff reg off)
	= CmmMachOp (MO_Add width) [CmmReg reg, CmmLit (CmmInt (fromIntegral off) width)]
	where width = typeWidth (cmmRegType dflags reg)

mangleIndexTree _ _
	= panic "SPARC.CodeGen.Base.mangleIndexTree: no match"




