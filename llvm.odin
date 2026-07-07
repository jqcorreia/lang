package main

// Links dynamically against the system LLVM-21 shared object by default, so a
// plain `odin build .` / `make` just works. To link LLVM statically instead,
// use ./build-static.sh — it shadows the -lLLVM-21 this emits with a stub archive
// and resolves the symbols from the static component libs (no source changes needed).
foreign import LLVM_C "system:LLVM-21"

import _c "core:c"

C_ANALYSIS_H :: 1
C_BITREADER_H :: 1
C_BITWRITER_H :: 1
C_BLAKE3_H :: 1
_BLAKE3_VERSION_STRING :: "1.3.1"
_BLAKE3_KEY_LEN :: 32
_BLAKE3_OUT_LEN :: 32
_BLAKE3_BLOCK_LEN :: 64
_BLAKE3CHUNK_LEN :: 1024
_BLAKE3_MAX_DEPTH :: 54
CCOMDAT_H :: 1
CCORE_H :: 1
C_DATATYPES_H :: 1
C_DEBUGINFO_H :: 1
C_DEPRECATED_H :: 1
C_DISASSEMBLER_H :: 1
Disassembler_Option_UseMarkup :: 1
Disassembler_Option_PrintImmHex :: 2
Disassembler_Option_AsmPrinterVariant :: 4
Disassembler_Option_SetInstrComments :: 8
Disassembler_Option_PrintLatency :: 16
C_DISASSEMBLERTYPES_H :: 1
Disassembler_VariantKind_None :: 0
Disassembler_VariantKind_ARM_HI16 :: 1
Disassembler_VariantKind_ARM_LO16 :: 2
Disassembler_VariantKind_ARM64_PAGE :: 1
Disassembler_VariantKind_ARM64_PAGEOFF :: 2
Disassembler_VariantKind_ARM64_GOTPAGE :: 3
Disassembler_VariantKind_ARM64_GOTPAGEOFF :: 4
Disassembler_VariantKind_ARM64_TLVP :: 5
Disassembler_VariantKind_ARM64_TLVOFF :: 6
Disassembler_ReferenceType_InOut_None :: 0
Disassembler_ReferenceType_In_Branch :: 1
Disassembler_ReferenceType_In_PCrel_Load :: 2
Disassembler_ReferenceType_In_ARM64_ADRP :: 4294967297
Disassembler_ReferenceType_In_ARM64_ADDXri :: 4294967298
Disassembler_ReferenceType_In_ARM64_LDRXui :: 4294967299
Disassembler_ReferenceType_In_ARM64_LDRXl :: 4294967300
Disassembler_ReferenceType_In_ARM64_ADR :: 4294967301
Disassembler_ReferenceType_Out_SymbolStub :: 1
Disassembler_ReferenceType_Out_LitPool_SymAddr :: 2
Disassembler_ReferenceType_Out_LitPoolCstrAddr :: 3
Disassembler_ReferenceType_Out_ObjcCFString_Ref :: 4
Disassembler_ReferenceType_Out_Objc_Message :: 5
Disassembler_ReferenceType_Out_Objc_Message_Ref :: 6
Disassembler_ReferenceType_Out_Objc_Selector_Ref :: 7
Disassembler_ReferenceType_Out_ObjcClass_Ref :: 8
Disassembler_ReferenceType_DeMangled_Name :: 9
C_ERROR_H :: 1
ErrorSuccess :: 0
C_ERRORHANDLING_H :: 1
C_EXECUTIONENGINE_H :: 1
C_EXTERNC_H :: 1
C_IRREADER_H :: 1
C_LINKER_H :: 1
C_LLJIT_H :: 1
C_LTO_H :: 1
LTO_API_VERSION :: 29
C_OBJECT_H :: 1
C_ORC_H :: 1
C_ORCEE_H :: 1
C_REMARKS_H :: 1
REMARKS_API_VERSION :: 1
C_SUPPORT_H :: 1
C_TARGET_H :: 1
C_TARGETMACHINE_H :: 1
C_TYPES_H :: 1

AttributeIndex :: _c.uint
DiagnosticHandler :: #type proc(unamed0: DiagnosticInfoRef, unamed1: rawptr)
YieldCallback :: #type proc(unamed0: ContextRef, unamed1: rawptr)
ssize_t :: i64
MetadataKind :: _c.uint
DWARFTypeEncoding :: _c.uint
DisasmContextRef :: rawptr
OpInfoCallback :: #type proc(
	DisInfo: rawptr,
	PC: u64,
	Offset: u64,
	OpSize: u64,
	InstSize: u64,
	TagType: _c.int,
	TagBuf: rawptr,
) -> _c.int
SymbolLookupCallback :: #type proc(
	DisInfo: rawptr,
	ReferenceValue: u64,
	ReferenceType: ^u64,
	ReferencePC: u64,
	ReferenceName: ^cstring,
) -> cstring
ErrorRef :: ^OpaqueError
ErrorTypeId :: rawptr
FatalErrorHandler :: #type proc(Reason: cstring)
GenericValueRef :: ^OpaqueGenericValue
ExecutionEngineRef :: ^OpaqueExecutionEngine
MCJITMemoryManagerRef :: ^OpaqueMCJITMemoryManager
MemoryManagerAllocateCodeSectionCallback :: #type proc(
	Opaque: rawptr,
	Size: _c.uintptr_t,
	Alignment: _c.uint,
	SectionID: _c.uint,
	SectionName: cstring,
) -> ^u8
MemoryManagerAllocateDataSectionCallback :: #type proc(
	Opaque: rawptr,
	Size: _c.uintptr_t,
	Alignment: _c.uint,
	SectionID: _c.uint,
	SectionName: cstring,
	IsReadOnly: LLVMBool,
) -> ^u8
MemoryManagerFinalizeMemoryCallback :: #type proc(Opaque: rawptr, ErrMsg: ^cstring) -> LLVMBool
MemoryManagerDestroyCallback :: #type proc(Opaque: rawptr)
OrcLLJITBuilderObjectLinkingLayerCreatorFunction :: #type proc(
	Ctx: rawptr,
	ES: OrcExecutionSessionRef,
	Triple: cstring,
) -> OrcObjectLayerRef
OrcLLJITBuilderRef :: ^OrcOpaqueLLJITBuilder
OrcLLJITRef :: ^OrcOpaqueLLJIT
lto_bool_t :: bool
lto_module_t :: ^OpaqueLTOModule
lto_code_gen_t :: ^OpaqueLTOCodeGenerator
thinlto_code_gen_t :: ^OpaqueThinLTOCodeGenerator
lto_diagnostic_handler_t :: #type proc(
	severity: lto_codegen_diagnostic_severity_t,
	diag: cstring,
	ctxt: rawptr,
)
lto_input_t :: ^OpaqueLTOInput
SectionIteratorRef :: ^OpaqueSectionIterator
SymbolIteratorRef :: ^OpaqueSymbolIterator
RelocationIteratorRef :: ^OpaqueRelocationIterator
ObjectFileRef :: ^OpaqueObjectFile
OrcJITTargetAddress :: u64
OrcExecutorAddress :: u64
JITSymbolTargetFlags :: u8
OrcExecutionSessionRef :: ^OrcOpaqueExecutionSession
OrcErrorReporterFunction :: #type proc(Ctx: rawptr, Err: ErrorRef)
OrcSymbolStringPoolRef :: ^OrcOpaqueSymbolStringPool
OrcSymbolStringPoolEntryRef :: ^OrcOpaqueSymbolStringPoolEntry
OrcCSymbolFlagsMapPairs :: ^OrcCSymbolFlagsMapPair
OrcCSymbolMapPairs :: ^OrcCSymbolMapPair
OrcCSymbolAliasMapPairs :: ^OrcCSymbolAliasMapPair
OrcJITDylibRef :: ^OrcOpaqueJITDylib
OrcCDependenceMapPairs :: ^OrcCDependenceMapPair
OrcCJITDylibSearchOrder :: ^OrcCJITDylibSearchOrderElement
OrcCLookupSet :: ^OrcCLookupSetElement
OrcMaterializationUnitRef :: ^OrcOpaqueMaterializationUnit
OrcMaterializationResponsibilityRef :: ^OrcOpaqueMaterializationResponsibility
OrcMaterializationUnitMaterializeFunction :: #type proc(
	Ctx: rawptr,
	MR: OrcMaterializationResponsibilityRef,
)
OrcMaterializationUnitDiscardFunction :: #type proc(
	Ctx: rawptr,
	JD: OrcJITDylibRef,
	Symbol: OrcSymbolStringPoolEntryRef,
)
OrcMaterializationUnitDestroyFunction :: #type proc(Ctx: rawptr)
OrcResourceTrackerRef :: ^OrcOpaqueResourceTracker
OrcDefinitionGeneratorRef :: ^OrcOpaqueDefinitionGenerator
OrcLookupStateRef :: ^OrcOpaqueLookupState
OrcCAPIDefinitionGeneratorTryToGenerateFunction :: #type proc(
	GeneratorObj: OrcDefinitionGeneratorRef,
	Ctx: rawptr,
	LookupState: ^OrcLookupStateRef,
	Kind: OrcLookupKind,
	JD: OrcJITDylibRef,
	JDLookupFlags: OrcJITDylibLookupFlags,
	LookupSet: OrcCLookupSet,
	LookupSetSize: _c.size_t,
) -> ErrorRef
OrcDisposeCAPIDefinitionGeneratorFunction :: #type proc(Ctx: rawptr)
OrcSymbolPredicate :: #type proc(Ctx: rawptr, Sym: OrcSymbolStringPoolEntryRef) -> _c.int
OrcThreadSafeContextRef :: ^OrcOpaqueThreadSafeContext
OrcThreadSafeModuleRef :: ^OrcOpaqueThreadSafeModule
OrcGenericIRModuleOperationFunction :: #type proc(Ctx: rawptr, M: ModuleRef) -> ErrorRef
OrcJITTargetMachineBuilderRef :: ^OrcOpaqueJITTargetMachineBuilder
OrcObjectLayerRef :: ^OrcOpaqueObjectLayer
OrcObjectLinkingLayerRef :: ^OrcOpaqueObjectLinkingLayer
OrcIRTransformLayerRef :: ^OrcOpaqueIRTransformLayer
OrcIRTransformLayerTransformFunction :: #type proc(
	Ctx: rawptr,
	ModInOut: ^OrcThreadSafeModuleRef,
	MR: OrcMaterializationResponsibilityRef,
) -> ErrorRef
OrcObjectTransformLayerRef :: ^OrcOpaqueObjectTransformLayer
OrcObjectTransformLayerTransformFunction :: #type proc(
	Ctx: rawptr,
	ObjInOut: ^MemoryBufferRef,
) -> ErrorRef
OrcIndirectStubsManagerRef :: ^OrcOpaqueIndirectStubsManager
OrcLazyCallThroughManagerRef :: ^OrcOpaqueLazyCallThroughManager
OrcDumpObjectsRef :: ^OrcOpaqueDumpObjects
OrcExecutionSessionLookupHandleResultFunction :: #type proc(
	Err: ErrorRef,
	Result: OrcCSymbolMapPairs,
	NumPairs: _c.size_t,
	Ctx: rawptr,
)
MemoryManagerCreateContextCallback :: #type proc(CtxCtx: rawptr) -> rawptr
MemoryManagerNotifyTerminatingCallback :: #type proc(CtxCtx: rawptr)
RemarkStringRef :: ^RemarkOpaqueString
RemarkDebugLocRef :: ^RemarkOpaqueDebugLoc
RemarkArgRef :: ^RemarkOpaqueArg
RemarkEntryRef :: ^RemarkOpaqueEntry
RemarkParserRef :: ^RemarkOpaqueParser
TargetDataRef :: ^OpaqueTargetData
TargetLibraryInfoRef :: ^OpaqueTargetLibraryInfotData
TargetMachineRef :: ^OpaqueTargetMachine
TargetRef :: ^Target
LLVMBool :: _c.int
MemoryBufferRef :: ^OpaqueMemoryBuffer
ContextRef :: ^OpaqueContext
ModuleRef :: ^OpaqueModule
TypeRef :: ^OpaqueType
ValueRef :: ^OpaqueValue
BasicBlockRef :: ^OpaqueBasicBlock
MetadataRef :: ^OpaqueMetadata
NamedMDNodeRef :: ^OpaqueNamedMDNode
ValueMetadataEntry :: OpaqueValueMetadataEntry
BuilderRef :: ^OpaqueBuilder
DIBuilderRef :: ^OpaqueDIBuilder
ModuleProviderRef :: ^OpaqueModuleProvider
PassManagerRef :: ^OpaquePassManager
UseRef :: ^OpaqueUse
AttributeRef :: ^OpaqueAttributeRef
DiagnosticInfoRef :: ^OpaqueDiagnosticInfo
ComdatRef :: ^Comdat
ModuleFlagEntry :: OpaqueModuleFlagEntry
JITEventListenerRef :: ^OpaqueJITEventListener
BinaryRef :: ^OpaqueBinary

VerifierFailureAction :: enum i32 {
	AbortProcessAction,
	PrintMessageAction,
	ReturnStatusAction,
}

ComdatSelectionKind :: enum i32 {
	AnyComdatSelectionKind,
	ExactMatchComdatSelectionKind,
	LargestComdatSelectionKind,
	NoDeduplicateComdatSelectionKind,
	SameSizeComdatSelectionKind,
}

Opcode :: enum i32 {
	Ret            = 1,
	Br             = 2,
	Switch         = 3,
	IndirectBr     = 4,
	Invoke         = 5,
	Unreachable    = 7,
	CallBr         = 67,
	FNeg           = 66,
	Add            = 8,
	FAdd           = 9,
	Sub            = 10,
	FSub           = 11,
	Mul            = 12,
	FMul           = 13,
	UDiv           = 14,
	SDiv           = 15,
	FDiv           = 16,
	URem           = 17,
	SRem           = 18,
	FRem           = 19,
	Shl            = 20,
	LShr           = 21,
	AShr           = 22,
	And            = 23,
	Or             = 24,
	Xor            = 25,
	Alloca         = 26,
	Load           = 27,
	Store          = 28,
	GetElementPtr  = 29,
	Trunc          = 30,
	ZExt           = 31,
	SExt           = 32,
	FPToUI         = 33,
	FPToSI         = 34,
	UIToFP         = 35,
	SIToFP         = 36,
	FPTrunc        = 37,
	FPExt          = 38,
	PtrToInt       = 39,
	IntToPtr       = 40,
	BitCast        = 41,
	AddrSpaceCast  = 60,
	ICmp           = 42,
	FCmp           = 43,
	PHI            = 44,
	Call           = 45,
	Select         = 46,
	UserOp1        = 47,
	UserOp2        = 48,
	VAArg          = 49,
	ExtractElement = 50,
	InsertElement  = 51,
	ShuffleVector  = 52,
	ExtractValue   = 53,
	InsertValue    = 54,
	Freeze         = 68,
	Fence          = 55,
	AtomicCmpXchg  = 56,
	AtomicRMW      = 57,
	Resume         = 58,
	LandingPad     = 59,
	CleanupRet     = 61,
	CatchRet       = 62,
	CatchPad       = 63,
	CleanupPad     = 64,
	CatchSwitch    = 65,
}

TypeKind :: enum i32 {
	VoidTypeKind,
	HalfTypeKind,
	FloatTypeKind,
	DoubleTypeKind,
	X86_FP80TypeKind,
	FP128TypeKind,
	PPC_FP128TypeKind,
	LabelTypeKind,
	IntegerTypeKind,
	FunctionTypeKind,
	StructTypeKind,
	ArrayTypeKind,
	PointerTypeKind,
	VectorTypeKind,
	MetadataTypeKind,
	X86_MMXTypeKind,
	TokenTypeKind,
	ScalableVectorTypeKind,
	BFloatTypeKind,
	X86_AMXTypeKind,
	TargetExtTypeKind,
}

Linkage :: enum i32 {
	ExternalLinkage,
	AvailableExternallyLinkage,
	LinkOnceAnyLinkage,
	LinkOnceODRLinkage,
	LinkOnceODRAutoHideLinkage,
	WeakAnyLinkage,
	WeakODRLinkage,
	AppendingLinkage,
	InternalLinkage,
	PrivateLinkage,
	DLLImportLinkage,
	DLLExportLinkage,
	ExternalWeakLinkage,
	GhostLinkage,
	CommonLinkage,
	LinkerPrivateLinkage,
	LinkerPrivateWeakLinkage,
}

Visibility :: enum i32 {
	DefaultVisibility,
	HiddenVisibility,
	ProtectedVisibility,
}

UnnamedAddr :: enum i32 {
	NoUnnamedAddr,
	LocalUnnamedAddr,
	GlobalUnnamedAddr,
}

DLLStorageClass :: enum i32 {
	DefaultStorageClass   = 0,
	DLLImportStorageClass = 1,
	DLLExportStorageClass = 2,
}

CallConv :: enum i32 {
	CCallConv             = 0,
	FastCallConv          = 8,
	ColdCallConv          = 9,
	GHCCallConv           = 10,
	HiPECallConv          = 11,
	WebKitJSCallConv      = 12,
	AnyRegCallConv        = 13,
	PreserveMostCallConv  = 14,
	PreserveAllCallConv   = 15,
	SwiftCallConv         = 16,
	CXXFASTTLSCallConv    = 17,
	X86StdcallCallConv    = 64,
	X86FastcallCallConv   = 65,
	ARMAPCSCallConv       = 66,
	ARMAAPCSCallConv      = 67,
	ARMAAPCSVFPCallConv   = 68,
	MSP430INTRCallConv    = 69,
	X86ThisCallCallConv   = 70,
	PTXKernelCallConv     = 71,
	PTXDeviceCallConv     = 72,
	SPIRFUNCCallConv      = 75,
	SPIRKERNELCallConv    = 76,
	IntelOCLBICallConv    = 77,
	X8664SysVCallConv     = 78,
	Win64CallConv         = 79,
	X86VectorCallCallConv = 80,
	HHVMCallConv          = 81,
	HHVMCCallConv         = 82,
	X86INTRCallConv       = 83,
	AVRINTRCallConv       = 84,
	AVRSIGNALCallConv     = 85,
	AVRBUILTINCallConv    = 86,
	AMDGPUVSCallConv      = 87,
	AMDGPUGSCallConv      = 88,
	AMDGPUPSCallConv      = 89,
	AMDGPUCSCallConv      = 90,
	AMDGPUKERNELCallConv  = 91,
	X86RegCallCallConv    = 92,
	AMDGPUHSCallConv      = 93,
	MSP430BUILTINCallConv = 94,
	AMDGPULSCallConv      = 95,
	AMDGPUESCallConv      = 96,
}

ValueKind :: enum i32 {
	ArgumentValueKind,
	BasicBlockValueKind,
	MemoryUseValueKind,
	MemoryDefValueKind,
	MemoryPhiValueKind,
	FunctionValueKind,
	GlobalAliasValueKind,
	GlobalIFuncValueKind,
	GlobalVariableValueKind,
	BlockAddressValueKind,
	ConstantExprValueKind,
	ConstantArrayValueKind,
	ConstantStructValueKind,
	ConstantVectorValueKind,
	UndefValueValueKind,
	ConstantAggregateZeroValueKind,
	ConstantDataArrayValueKind,
	ConstantDataVectorValueKind,
	ConstantIntValueKind,
	ConstantFPValueKind,
	ConstantPointerNullValueKind,
	ConstantTokenNoneValueKind,
	MetadataAsValueValueKind,
	InlineAsmValueKind,
	InstructionValueKind,
	PoisonValueValueKind,
	ConstantTargetNoneValueKind,
}

IntPredicate :: enum i32 {
	IntEQ = 32,
	IntNE,
	IntUGT,
	IntUGE,
	IntULT,
	IntULE,
	IntSGT,
	IntSGE,
	IntSLT,
	IntSLE,
}

RealPredicate :: enum i32 {
	RealPredicateFalse,
	RealOEQ,
	RealOGT,
	RealOGE,
	RealOLT,
	RealOLE,
	RealONE,
	RealORD,
	RealUNO,
	RealUEQ,
	RealUGT,
	RealUGE,
	RealULT,
	RealULE,
	RealUNE,
	RealPredicateTrue,
}

LandingPadClauseTy :: enum i32 {
	LandingPadCatch,
	LandingPadFilter,
}

ThreadLocalMode :: enum i32 {
	NotThreadLocal = 0,
	GeneralDynamicTLSModel,
	LocalDynamicTLSModel,
	InitialExecTLSModel,
	LocalExecTLSModel,
}

AtomicOrdering :: enum i32 {
	AtomicOrderingNotAtomic              = 0,
	AtomicOrderingUnordered              = 1,
	AtomicOrderingMonotonic              = 2,
	AtomicOrderingAcquire                = 4,
	AtomicOrderingRelease                = 5,
	AtomicOrderingAcquireRelease         = 6,
	AtomicOrderingSequentiallyConsistent = 7,
}

AtomicRMWBinOp :: enum i32 {
	AtomicRMWBinOpXchg,
	AtomicRMWBinOpAdd,
	AtomicRMWBinOpSub,
	AtomicRMWBinOpAnd,
	AtomicRMWBinOpNand,
	AtomicRMWBinOpOr,
	AtomicRMWBinOpXor,
	AtomicRMWBinOpMax,
	AtomicRMWBinOpMin,
	AtomicRMWBinOpUMax,
	AtomicRMWBinOpUMin,
	AtomicRMWBinOpFAdd,
	AtomicRMWBinOpFSub,
	AtomicRMWBinOpFMax,
	AtomicRMWBinOpFMin,
}

DiagnosticSeverity :: enum i32 {
	DSError,
	DSWarning,
	DSRemark,
	DSNote,
}

InlineAsmDialect :: enum i32 {
	InlineAsmDialectATT,
	InlineAsmDialectIntel,
}

ModuleFlagBehavior :: enum i32 {
	ModuleFlagBehaviorError,
	ModuleFlagBehaviorWarning,
	ModuleFlagBehaviorRequire,
	ModuleFlagBehaviorOverride,
	ModuleFlagBehaviorAppend,
	ModuleFlagBehaviorAppendUnique,
}

AnonymousEnum19 :: enum i32 {
	AttributeReturnIndex   = 0,
	AttributeFunctionIndex = -1,
}

DIFlags :: enum i32 {
	DIFlagZero                = 0,
	DIFlagPrivate             = 1,
	DIFlagProtected           = 2,
	DIFlagPublic              = 3,
	DIFlagFwdDecl             = 4,
	DIFlagAppleBlock          = 8,
	DIFlagReservedBit4        = 16,
	DIFlagVirtual             = 32,
	DIFlagArtificial          = 64,
	DIFlagExplicit            = 128,
	DIFlagPrototyped          = 256,
	DIFlagObjcClassComplete   = 512,
	DIFlagObjectPointer       = 1024,
	DIFlagVector              = 2048,
	DIFlagStaticMember        = 4096,
	DIFlagLValueReference     = 8192,
	DIFlagRValueReference     = 16384,
	DIFlagReserved            = 32768,
	DIFlagSingleInheritance   = 65536,
	DIFlagMultipleInheritance = 131072,
	DIFlagVirtualInheritance  = 196608,
	DIFlagIntroducedVirtual   = 262144,
	DIFlagBitField            = 524288,
	DIFlagNoReturn            = 1048576,
	DIFlagTypePassByValue     = 4194304,
	DIFlagTypePassByReference = 8388608,
	DIFlagEnumClass           = 16777216,
	DIFlagFixedEnum           = 16777216,
	DIFlagThunk               = 33554432,
	DIFlagNonTrivial          = 67108864,
	DIFlagBigEndian           = 134217728,
	DIFlagLittleEndian        = 268435456,
	DIFlagIndirectVirtualBase = 4,
	DIFlagAccessibility       = 1,
	DIFlagPtrToMemberRep      = 65536,
}

DWARFSourceLanguage :: enum i32 {
	DWARFSourceLanguageC89,
	DWARFSourceLanguageC,
	DWARFSourceLanguageAda83,
	DWARFSourceLanguageC_plus_plus,
	DWARFSourceLanguageCobol74,
	DWARFSourceLanguageCobol85,
	DWARFSourceLanguageFortran77,
	DWARFSourceLanguageFortran90,
	DWARFSourceLanguagePascal83,
	DWARFSourceLanguageModula2,
	DWARFSourceLanguageJava,
	DWARFSourceLanguageC99,
	DWARFSourceLanguageAda95,
	DWARFSourceLanguageFortran95,
	DWARFSourceLanguagePLI,
	DWARFSourceLanguageObjC,
	DWARFSourceLanguageObjC_plus_plus,
	DWARFSourceLanguageUPC,
	DWARFSourceLanguageD,
	DWARFSourceLanguagePython,
	DWARFSourceLanguageOpenCL,
	DWARFSourceLanguageGo,
	DWARFSourceLanguageModula3,
	DWARFSourceLanguageHaskell,
	DWARFSourceLanguageC_plus_plus_03,
	DWARFSourceLanguageC_plus_plus_11,
	DWARFSourceLanguageOCaml,
	DWARFSourceLanguageRust,
	DWARFSourceLanguageC11,
	DWARFSourceLanguageSwift,
	DWARFSourceLanguageJulia,
	DWARFSourceLanguageDylan,
	DWARFSourceLanguageC_plus_plus_14,
	DWARFSourceLanguageFortran03,
	DWARFSourceLanguageFortran08,
	DWARFSourceLanguageRenderScript,
	DWARFSourceLanguageBLISS,
	DWARFSourceLanguageKotlin,
	DWARFSourceLanguageZig,
	DWARFSourceLanguageCrystal,
	DWARFSourceLanguageC_plus_plus_17,
	DWARFSourceLanguageC_plus_plus_20,
	DWARFSourceLanguageC17,
	DWARFSourceLanguageFortran18,
	DWARFSourceLanguageAda2005,
	DWARFSourceLanguageAda2012,
	DWARFSourceLanguageMojo,
	DWARFSourceLanguageMips_Assembler,
	DWARFSourceLanguageGOOGLE_RenderScript,
	DWARFSourceLanguageBORLAND_Delphi,
}

DWARFEmissionKind :: enum i32 {
	DWARFEmissionNone = 0,
	DWARFEmissionFull,
	DWARFEmissionLineTablesOnly,
}

AnonymousEnum23 :: enum i32 {
	MDStringMetadataKind,
	ConstantAsMetadataMetadataKind,
	LocalAsMetadataMetadataKind,
	DistinctMDOperandPlaceholderMetadataKind,
	MDTupleMetadataKind,
	DILocationMetadataKind,
	DIExpressionMetadataKind,
	DIGlobalVariableExpressionMetadataKind,
	GenericDINodeMetadataKind,
	DISubrangeMetadataKind,
	DIEnumeratorMetadataKind,
	DIBasicTypeMetadataKind,
	DIDerivedTypeMetadataKind,
	DICompositeTypeMetadataKind,
	DISubroutineTypeMetadataKind,
	DIFileMetadataKind,
	DICompileUnitMetadataKind,
	DISubprogramMetadataKind,
	DILexicalBlockMetadataKind,
	DILexicalBlockFileMetadataKind,
	DINamespaceMetadataKind,
	DIModuleMetadataKind,
	DITemplateTypeParameterMetadataKind,
	DITemplateValueParameterMetadataKind,
	DIGlobalVariableMetadataKind,
	DILocalVariableMetadataKind,
	DILabelMetadataKind,
	DIObjCPropertyMetadataKind,
	DIImportedEntityMetadataKind,
	DIMacroMetadataKind,
	DIMacroFileMetadataKind,
	DICommonBlockMetadataKind,
	DIStringTypeMetadataKind,
	DIGenericSubrangeMetadataKind,
	DIArgListMetadataKind,
	DIAssignIDMetadataKind,
}

DWARFMacinfoRecordType :: enum i32 {
	DWARFMacinfoRecordTypeDefine    = 1,
	DWARFMacinfoRecordTypeMacro     = 2,
	DWARFMacinfoRecordTypeStartFile = 3,
	DWARFMacinfoRecordTypeEndFile   = 4,
	DWARFMacinfoRecordTypeVendorExt = 255,
}

LinkerMode :: enum i32 {
	LinkerDestroySource          = 0,
	LinkerPreserveSource_Removed = 1,
}

lto_symbol_attributes :: enum i32 {
	LTO_SYMBOL_ALIGNMENT_MASK              = 31,
	LTO_SYMBOL_PERMISSIONS_MASK            = 224,
	LTO_SYMBOL_PERMISSIONS_CODE            = 160,
	LTO_SYMBOL_PERMISSIONS_DATA            = 192,
	LTO_SYMBOL_PERMISSIONS_RODATA          = 128,
	LTO_SYMBOL_DEFINITION_MASK             = 1792,
	LTO_SYMBOL_DEFINITION_REGULAR          = 256,
	LTO_SYMBOL_DEFINITION_TENTATIVE        = 512,
	LTO_SYMBOL_DEFINITION_WEAK             = 768,
	LTO_SYMBOL_DEFINITION_UNDEFINED        = 1024,
	LTO_SYMBOL_DEFINITION_WEAKUNDEF        = 1280,
	LTO_SYMBOL_SCOPE_MASK                  = 14336,
	LTO_SYMBOL_SCOPE_INTERNAL              = 2048,
	LTO_SYMBOL_SCOPE_HIDDEN                = 4096,
	LTO_SYMBOL_SCOPE_PROTECTED             = 8192,
	LTO_SYMBOL_SCOPE_DEFAULT               = 6144,
	LTO_SYMBOL_SCOPE_DEFAULT_CAN_BE_HIDDEN = 10240,
	LTO_SYMBOL_COMDAT                      = 16384,
	LTO_SYMBOL_ALIAS                       = 32768,
}

lto_debug_model :: enum i32 {
	LTO_DEBUG_MODEL_NONE  = 0,
	LTO_DEBUG_MODEL_DWARF = 1,
}

lto_codegen_model :: enum i32 {
	LTO_CODEGEN_PIC_MODEL_STATIC         = 0,
	LTO_CODEGEN_PIC_MODEL_DYNAMIC        = 1,
	LTO_CODEGEN_PIC_MODEL_DYNAMIC_NO_PIC = 2,
	LTO_CODEGEN_PIC_MODEL_DEFAULT        = 3,
}

lto_codegen_diagnostic_severity_t :: enum i32 {
	LTO_DS_ERROR   = 0,
	LTO_DS_WARNING = 1,
	LTO_DS_REMARK  = 3,
	LTO_DS_NOTE    = 2,
}

BinaryType :: enum i32 {
	BinaryTypeArchive,
	BinaryTypeMachOUniversalBinary,
	BinaryTypeCOFFImportFile,
	BinaryTypeIR,
	BinaryTypeWinRes,
	BinaryTypeCOFF,
	BinaryTypeELF32L,
	BinaryTypeELF32B,
	BinaryTypeELF64L,
	BinaryTypeELF64B,
	BinaryTypeMachO32L,
	BinaryTypeMachO32B,
	BinaryTypeMachO64L,
	BinaryTypeMachO64B,
	BinaryTypeWasm,
	BinaryTypeOffload,
}

JITSymbolGenericFlags :: enum i32 {
	JITSymbolGenericFlagsNone                           = 0,
	JITSymbolGenericFlagsExported                       = 1,
	JITSymbolGenericFlagsWeak                           = 2,
	JITSymbolGenericFlagsCallable                       = 4,
	JITSymbolGenericFlagsMaterializationSideEffectsOnly = 8,
}

OrcLookupKind :: enum i32 {
	OrcLookupKindStatic,
	OrcLookupKindDLSym,
}

OrcJITDylibLookupFlags :: enum i32 {
	OrcJITDylibLookupFlagsMatchExportedSymbolsOnly,
	OrcJITDylibLookupFlagsMatchAllSymbols,
}

OrcSymbolLookupFlags :: enum i32 {
	OrcSymbolLookupFlagsRequiredSymbol,
	OrcSymbolLookupFlagsWeaklyReferencedSymbol,
}

RemarkType :: enum i32 {
	RemarkTypeUnknown,
	RemarkTypePassed,
	RemarkTypeMissed,
	RemarkTypeAnalysis,
	RemarkTypeAnalysisFPCommute,
	RemarkTypeAnalysisAliasing,
	RemarkTypeFailure,
}

ByteOrdering :: enum i32 {
	BigEndian,
	LittleEndian,
}

CodeGenOptLevel :: enum i32 {
	CodeGenLevelNone,
	CodeGenLevelLess,
	CodeGenLevelDefault,
	CodeGenLevelAggressive,
}

RelocMode :: enum i32 {
	RelocDefault,
	RelocStatic,
	RelocPIC,
	RelocDynamicNoPic,
	RelocROPI,
	RelocRWPI,
	RelocROPI_RWPI,
}

CodeModel :: enum i32 {
	CodeModelDefault,
	CodeModelJITDefault,
	CodeModelTiny,
	CodeModelSmall,
	CodeModelKernel,
	CodeModelMedium,
	CodeModelLarge,
}

CodeGenFileType :: enum i32 {
	AssemblyFile,
	ObjectFile,
}

_blake3_chunk_state :: struct {
	cv:                [8]u32,
	chunk_counter:     u64,
	buf:               [64]u8,
	buf_len:           u8,
	blocks_compressed: u8,
	flags:             u8,
}

_blake3_hasher :: struct {
	key:          [8]u32,
	chunk:        _blake3_chunk_state,
	cv_stack_len: u8,
	cv_stack:     [1760]u8,
}

OpInfoSymbol1 :: struct {
	Present: u64,
	Name:    cstring,
	Value:   u64,
}

OpInfo1 :: struct {
	AddSymbol:      OpInfoSymbol1,
	SubtractSymbol: OpInfoSymbol1,
	Value:          u64,
	VariantKind:    u64,
}

OpaqueError :: struct {}

OpaqueGenericValue :: struct {}

OpaqueExecutionEngine :: struct {}

OpaqueMCJITMemoryManager :: struct {}

MCJITCompilerOptions :: struct {
	OptLevel:           _c.uint,
	CodeModel:          CodeModel,
	NoFramePointerElim: LLVMBool,
	EnableFastISel:     LLVMBool,
	MCJMM:              MCJITMemoryManagerRef,
}

OrcOpaqueLLJITBuilder :: struct {}

OrcOpaqueLLJIT :: struct {}

OpaqueLTOModule :: struct {}

OpaqueLTOCodeGenerator :: struct {}

OpaqueThinLTOCodeGenerator :: struct {}

OpaqueLTOInput :: struct {}

LTOObjectBuffer :: struct {
	Buffer: cstring,
	Size:   _c.size_t,
}

OpaqueSectionIterator :: struct {}

OpaqueSymbolIterator :: struct {}

OpaqueRelocationIterator :: struct {}

OpaqueObjectFile :: struct {}

JITSymbolFlags :: struct {
	GenericFlags: u8,
	TargetFlags:  u8,
}

JITEvaluatedSymbol :: struct {
	Address: u64,
	Flags:   JITSymbolFlags,
}

OrcOpaqueExecutionSession :: struct {}

OrcOpaqueSymbolStringPool :: struct {}

OrcOpaqueSymbolStringPoolEntry :: struct {}

OrcCSymbolFlagsMapPair :: struct {
	Name:  OrcSymbolStringPoolEntryRef,
	Flags: JITSymbolFlags,
}

OrcCSymbolMapPair :: struct {
	Name: OrcSymbolStringPoolEntryRef,
	Sym:  JITEvaluatedSymbol,
}

OrcCSymbolAliasMapEntry :: struct {
	Name:  OrcSymbolStringPoolEntryRef,
	Flags: JITSymbolFlags,
}

OrcCSymbolAliasMapPair :: struct {
	Name:  OrcSymbolStringPoolEntryRef,
	Entry: OrcCSymbolAliasMapEntry,
}

OrcOpaqueJITDylib :: struct {}

OrcCSymbolsList :: struct {
	Symbols: ^OrcSymbolStringPoolEntryRef,
	Length:  _c.size_t,
}

OrcCDependenceMapPair :: struct {
	JD:    OrcJITDylibRef,
	Names: OrcCSymbolsList,
}

OrcCJITDylibSearchOrderElement :: struct {
	JD:            OrcJITDylibRef,
	JDLookupFlags: OrcJITDylibLookupFlags,
}

OrcCLookupSetElement :: struct {
	Name:        OrcSymbolStringPoolEntryRef,
	LookupFlags: OrcSymbolLookupFlags,
}

OrcOpaqueMaterializationUnit :: struct {}

OrcOpaqueMaterializationResponsibility :: struct {}

OrcOpaqueResourceTracker :: struct {}

OrcOpaqueDefinitionGenerator :: struct {}

OrcOpaqueLookupState :: struct {}

OrcOpaqueThreadSafeContext :: struct {}

OrcOpaqueThreadSafeModule :: struct {}

OrcOpaqueJITTargetMachineBuilder :: struct {}

OrcOpaqueObjectLayer :: struct {}

OrcOpaqueObjectLinkingLayer :: struct {}

OrcOpaqueIRTransformLayer :: struct {}

OrcOpaqueObjectTransformLayer :: struct {}

OrcOpaqueIndirectStubsManager :: struct {}

OrcOpaqueLazyCallThroughManager :: struct {}

OrcOpaqueDumpObjects :: struct {}

RemarkOpaqueString :: struct {}

RemarkOpaqueDebugLoc :: struct {}

RemarkOpaqueArg :: struct {}

RemarkOpaqueEntry :: struct {}

RemarkOpaqueParser :: struct {}

OpaqueTargetData :: struct {}

OpaqueTargetLibraryInfotData :: struct {}

OpaqueTargetMachine :: struct {}

Target :: struct {}

OpaqueMemoryBuffer :: struct {}

OpaqueContext :: struct {}

OpaqueModule :: struct {}

OpaqueType :: struct {}

OpaqueValue :: struct {}

OpaqueBasicBlock :: struct {}

OpaqueMetadata :: struct {}

OpaqueNamedMDNode :: struct {}

OpaqueValueMetadataEntry :: struct {}

OpaqueBuilder :: struct {}

OpaqueDIBuilder :: struct {}

OpaqueModuleProvider :: struct {}

OpaquePassManager :: struct {}

OpaqueUse :: struct {}

OpaqueAttributeRef :: struct {}

OpaqueDiagnosticInfo :: struct {}

Comdat :: struct {}

OpaqueModuleFlagEntry :: struct {}

OpaqueJITEventListener :: struct {}

OpaqueBinary :: struct {}

@(default_calling_convention = "c", link_prefix = "LLVM")
foreign LLVM_C {
	VerifyModule :: proc(M: ModuleRef, Action: VerifierFailureAction, OutMessage: ^cstring) -> LLVMBool ---
	VerifyFunction :: proc(Fn: ValueRef, Action: VerifierFailureAction) -> LLVMBool ---
	ViewFunctionCFG :: proc(Fn: ValueRef) ---
	ViewFunctionCFGOnly :: proc(Fn: ValueRef) ---
	ParseBitcode :: proc(MemBuf: MemoryBufferRef, OutModule: ^ModuleRef, OutMessage: ^cstring) -> LLVMBool ---
	ParseBitcode2 :: proc(MemBuf: MemoryBufferRef, OutModule: ^ModuleRef) -> LLVMBool ---
	ParseBitcodeInContext :: proc(ContextRef: ContextRef, MemBuf: MemoryBufferRef, OutModule: ^ModuleRef, OutMessage: ^cstring) -> LLVMBool ---
	ParseBitcodeInContext2 :: proc(ContextRef: ContextRef, MemBuf: MemoryBufferRef, OutModule: ^ModuleRef) -> LLVMBool ---
	GetBitcodeModuleInContext :: proc(ContextRef: ContextRef, MemBuf: MemoryBufferRef, OutM: ^ModuleRef, OutMessage: ^cstring) -> LLVMBool ---
	GetBitcodeModuleInContext2 :: proc(ContextRef: ContextRef, MemBuf: MemoryBufferRef, OutM: ^ModuleRef) -> LLVMBool ---
	GetBitcodeModule :: proc(MemBuf: MemoryBufferRef, OutM: ^ModuleRef, OutMessage: ^cstring) -> LLVMBool ---
	GetBitcodeModule2 :: proc(MemBuf: MemoryBufferRef, OutM: ^ModuleRef) -> LLVMBool ---
	WriteBitcodeToFile :: proc(M: ModuleRef, Path: cstring) -> _c.int ---
	WriteBitcodeToFD :: proc(M: ModuleRef, FD: _c.int, ShouldClose: _c.int, Unbuffered: _c.int) -> _c.int ---
	WriteBitcodeToFileHandle :: proc(M: ModuleRef, Handle: _c.int) -> _c.int ---
	WriteBitcodeToMemoryBuffer :: proc(M: ModuleRef) -> MemoryBufferRef ---

	@(link_name = "llvm_blake3_version")
	_blake3_version :: proc() -> cstring ---

	@(link_name = "llvm_blake3_hasher_init")
	_blake3_hasher_init :: proc(self: ^_blake3_hasher) ---

	@(link_name = "llvm_blake3_hasher_init_keyed")
	_blake3_hasher_init_keyed :: proc(self: ^_blake3_hasher, key: [32]u8) ---

	@(link_name = "llvm_blake3_hasher_init_derive_key")
	_blake3_hasher_init_derive_key :: proc(self: ^_blake3_hasher, _context: cstring) ---

	@(link_name = "llvm_blake3_hasher_init_derive_key_raw")
	_blake3_hasher_init_derive_key_raw :: proc(self: ^_blake3_hasher, _context: rawptr, context_len: _c.size_t) ---

	@(link_name = "llvm_blake3_hasher_update")
	_blake3_hasher_update :: proc(self: ^_blake3_hasher, input: rawptr, input_len: _c.size_t) ---

	@(link_name = "llvm_blake3_hasher_finalize")
	_blake3_hasher_finalize :: proc(self: ^_blake3_hasher, out: ^u8, out_len: _c.size_t) ---

	@(link_name = "llvm_blake3_hasher_finalize_seek")
	_blake3_hasher_finalize_seek :: proc(self: ^_blake3_hasher, seek: u64, out: ^u8, out_len: _c.size_t) ---

	@(link_name = "llvm_blake3_hasher_reset")
	_blake3_hasher_reset :: proc(self: ^_blake3_hasher) ---
	GetOrInsertComdat :: proc(M: ModuleRef, Name: cstring) -> ComdatRef ---
	GetComdat :: proc(V: ValueRef) -> ComdatRef ---
	SetComdat :: proc(V: ValueRef, C: ComdatRef) ---
	GetComdatSelectionKind :: proc(C: ComdatRef) -> ComdatSelectionKind ---
	SetComdatSelectionKind :: proc(C: ComdatRef, Kind: ComdatSelectionKind) ---
	Shutdown :: proc() ---
	GetVersion :: proc(Major: ^_c.uint, Minor: ^_c.uint, Patch: ^_c.uint) ---
	CreateMessage :: proc(Message: cstring) -> cstring ---
	DisposeMessage :: proc(Message: cstring) ---
	ContextCreate :: proc() -> ContextRef ---
	GetGlobalContext :: proc() -> ContextRef ---
	ContextSetDiagnosticHandler :: proc(C: ContextRef, Handler: DiagnosticHandler, DiagnosticContext: rawptr) ---
	ContextGetDiagnosticHandler :: proc(C: ContextRef) -> DiagnosticHandler ---
	ContextGetDiagnosticContext :: proc(C: ContextRef) -> rawptr ---
	ContextSetYieldCallback :: proc(C: ContextRef, Callback: YieldCallback, OpaqueHandle: rawptr) ---
	ContextShouldDiscardValueNames :: proc(C: ContextRef) -> LLVMBool ---
	ContextSetDiscardValueNames :: proc(C: ContextRef, Discard: LLVMBool) ---
	ContextDispose :: proc(C: ContextRef) ---
	GetDiagInfoDescription :: proc(DI: DiagnosticInfoRef) -> cstring ---
	GetDiagInfoSeverity :: proc(DI: DiagnosticInfoRef) -> DiagnosticSeverity ---
	GetMDKindIDInContext :: proc(C: ContextRef, Name: cstring, SLen: _c.uint) -> _c.uint ---
	GetMDKindID :: proc(Name: cstring, SLen: _c.uint) -> _c.uint ---
	GetEnumAttributeKindForName :: proc(Name: cstring, SLen: _c.size_t) -> _c.uint ---
	GetLastEnumAttributeKind :: proc() -> _c.uint ---
	CreateEnumAttribute :: proc(C: ContextRef, KindID: _c.uint, Val: u64) -> AttributeRef ---
	GetEnumAttributeKind :: proc(A: AttributeRef) -> _c.uint ---
	GetEnumAttributeValue :: proc(A: AttributeRef) -> u64 ---
	CreateTypeAttribute :: proc(C: ContextRef, KindID: _c.uint, type_ref: TypeRef) -> AttributeRef ---
	GetTypeAttributeValue :: proc(A: AttributeRef) -> TypeRef ---
	CreateStringAttribute :: proc(C: ContextRef, K: cstring, KLength: _c.uint, V: cstring, VLength: _c.uint) -> AttributeRef ---
	GetStringAttributeKind :: proc(A: AttributeRef, Length: ^_c.uint) -> cstring ---
	GetStringAttributeValue :: proc(A: AttributeRef, Length: ^_c.uint) -> cstring ---
	IsEnumAttribute :: proc(A: AttributeRef) -> LLVMBool ---
	IsStringAttribute :: proc(A: AttributeRef) -> LLVMBool ---
	IsTypeAttribute :: proc(A: AttributeRef) -> LLVMBool ---
	GetTypeByName2 :: proc(C: ContextRef, Name: cstring) -> TypeRef ---
	ModuleCreateWithName :: proc(ModuleID: cstring) -> ModuleRef ---
	ModuleCreateWithNameInContext :: proc(ModuleID: cstring, C: ContextRef) -> ModuleRef ---
	CloneModule :: proc(M: ModuleRef) -> ModuleRef ---
	DisposeModule :: proc(M: ModuleRef) ---
	GetModuleIdentifier :: proc(M: ModuleRef, Len: ^_c.size_t) -> cstring ---
	SetModuleIdentifier :: proc(M: ModuleRef, Ident: cstring, Len: _c.size_t) ---
	GetSourceFileName :: proc(M: ModuleRef, Len: ^_c.size_t) -> cstring ---
	SetSourceFileName :: proc(M: ModuleRef, Name: cstring, Len: _c.size_t) ---
	GetDataLayoutStr :: proc(M: ModuleRef) -> cstring ---
	GetDataLayout :: proc(M: ModuleRef) -> cstring ---
	SetDataLayout :: proc(M: ModuleRef, DataLayoutStr: cstring) ---
	GetTarget :: proc(M: ModuleRef) -> cstring ---
	SetTarget :: proc(M: ModuleRef, Triple: cstring) ---
	CopyModuleFlagsMetadata :: proc(M: ModuleRef, Len: ^_c.size_t) -> ^ModuleFlagEntry ---
	DisposeModuleFlagsMetadata :: proc(Entries: ^ModuleFlagEntry) ---
	ModuleFlagEntriesGetFlagBehavior :: proc(Entries: ^ModuleFlagEntry, Index: _c.uint) -> ModuleFlagBehavior ---
	ModuleFlagEntriesGetKey :: proc(Entries: ^ModuleFlagEntry, Index: _c.uint, Len: ^_c.size_t) -> cstring ---
	ModuleFlagEntriesGetMetadata :: proc(Entries: ^ModuleFlagEntry, Index: _c.uint) -> MetadataRef ---
	GetModuleFlag :: proc(M: ModuleRef, Key: cstring, KeyLen: _c.size_t) -> MetadataRef ---
	AddModuleFlag :: proc(M: ModuleRef, Behavior: ModuleFlagBehavior, Key: cstring, KeyLen: _c.size_t, Val: MetadataRef) ---
	DumpModule :: proc(M: ModuleRef) ---
	PrintModuleToFile :: proc(M: ModuleRef, Filename: cstring, ErrorMessage: ^cstring) -> LLVMBool ---
	PrintModuleToString :: proc(M: ModuleRef) -> cstring ---
	GetModuleInlineAsm :: proc(M: ModuleRef, Len: ^_c.size_t) -> cstring ---
	SetModuleInlineAsm2 :: proc(M: ModuleRef, Asm: cstring, Len: _c.size_t) ---
	AppendModuleInlineAsm :: proc(M: ModuleRef, Asm: cstring, Len: _c.size_t) ---
	GetInlineAsm :: proc(Ty: TypeRef, AsmString: cstring, AsmStringSize: _c.size_t, Constraints: cstring, ConstraintsSize: _c.size_t, HasSideEffects: LLVMBool, IsAlignStack: LLVMBool, Dialect: InlineAsmDialect, CanThrow: LLVMBool) -> ValueRef ---
	GetModuleContext :: proc(M: ModuleRef) -> ContextRef ---
	GetTypeByName :: proc(M: ModuleRef, Name: cstring) -> TypeRef ---
	GetFirstNamedMetadata :: proc(M: ModuleRef) -> NamedMDNodeRef ---
	GetLastNamedMetadata :: proc(M: ModuleRef) -> NamedMDNodeRef ---
	GetNextNamedMetadata :: proc(NamedMDNode: NamedMDNodeRef) -> NamedMDNodeRef ---
	GetPreviousNamedMetadata :: proc(NamedMDNode: NamedMDNodeRef) -> NamedMDNodeRef ---
	GetNamedMetadata :: proc(M: ModuleRef, Name: cstring, NameLen: _c.size_t) -> NamedMDNodeRef ---
	GetOrInsertNamedMetadata :: proc(M: ModuleRef, Name: cstring, NameLen: _c.size_t) -> NamedMDNodeRef ---
	GetNamedMetadataName :: proc(NamedMD: NamedMDNodeRef, NameLen: ^_c.size_t) -> cstring ---
	GetNamedMetadataNumOperands :: proc(M: ModuleRef, Name: cstring) -> _c.uint ---
	GetNamedMetadataOperands :: proc(M: ModuleRef, Name: cstring, Dest: ^ValueRef) ---
	AddNamedMetadataOperand :: proc(M: ModuleRef, Name: cstring, Val: ValueRef) ---
	GetDebugLocDirectory :: proc(Val: ValueRef, Length: ^_c.uint) -> cstring ---
	GetDebugLocFilename :: proc(Val: ValueRef, Length: ^_c.uint) -> cstring ---
	GetDebugLocLine :: proc(Val: ValueRef) -> _c.uint ---
	GetDebugLocColumn :: proc(Val: ValueRef) -> _c.uint ---
	AddFunction :: proc(M: ModuleRef, Name: cstring, FunctionTy: TypeRef) -> ValueRef ---
	GetNamedFunction :: proc(M: ModuleRef, Name: cstring) -> ValueRef ---
	GetFirstFunction :: proc(M: ModuleRef) -> ValueRef ---
	GetLastFunction :: proc(M: ModuleRef) -> ValueRef ---
	GetNextFunction :: proc(Fn: ValueRef) -> ValueRef ---
	GetPreviousFunction :: proc(Fn: ValueRef) -> ValueRef ---
	SetModuleInlineAsm :: proc(M: ModuleRef, Asm: cstring) ---
	GetTypeKind :: proc(Ty: TypeRef) -> TypeKind ---
	TypeIsSized :: proc(Ty: TypeRef) -> LLVMBool ---
	GetTypeContext :: proc(Ty: TypeRef) -> ContextRef ---
	DumpType :: proc(Val: TypeRef) ---
	PrintTypeToString :: proc(Val: TypeRef) -> cstring ---
	Int1TypeInContext :: proc(C: ContextRef) -> TypeRef ---
	Int8TypeInContext :: proc(C: ContextRef) -> TypeRef ---
	Int16TypeInContext :: proc(C: ContextRef) -> TypeRef ---
	Int32TypeInContext :: proc(C: ContextRef) -> TypeRef ---
	Int64TypeInContext :: proc(C: ContextRef) -> TypeRef ---
	Int128TypeInContext :: proc(C: ContextRef) -> TypeRef ---
	IntTypeInContext :: proc(C: ContextRef, NumBits: _c.uint) -> TypeRef ---
	Int1Type :: proc() -> TypeRef ---
	Int8Type :: proc() -> TypeRef ---
	Int16Type :: proc() -> TypeRef ---
	Int32Type :: proc() -> TypeRef ---
	Int64Type :: proc() -> TypeRef ---
	Int128Type :: proc() -> TypeRef ---
	IntType :: proc(NumBits: _c.uint) -> TypeRef ---
	GetIntTypeWidth :: proc(IntegerTy: TypeRef) -> _c.uint ---
	HalfTypeInContext :: proc(C: ContextRef) -> TypeRef ---
	BFloatTypeInContext :: proc(C: ContextRef) -> TypeRef ---
	FloatTypeInContext :: proc(C: ContextRef) -> TypeRef ---
	DoubleTypeInContext :: proc(C: ContextRef) -> TypeRef ---
	X86FP80TypeInContext :: proc(C: ContextRef) -> TypeRef ---
	FP128TypeInContext :: proc(C: ContextRef) -> TypeRef ---
	PPCFP128TypeInContext :: proc(C: ContextRef) -> TypeRef ---
	HalfType :: proc() -> TypeRef ---
	BFloatType :: proc() -> TypeRef ---
	FloatType :: proc() -> TypeRef ---
	DoubleType :: proc() -> TypeRef ---
	X86FP80Type :: proc() -> TypeRef ---
	FP128Type :: proc() -> TypeRef ---
	PPCFP128Type :: proc() -> TypeRef ---
	FunctionType :: proc(ReturnType: TypeRef, ParamTypes: ^TypeRef, ParamCount: _c.uint, IsVarArg: LLVMBool) -> TypeRef ---
	IsFunctionVarArg :: proc(FunctionTy: TypeRef) -> LLVMBool ---
	GetReturnType :: proc(FunctionTy: TypeRef) -> TypeRef ---
	CountParamTypes :: proc(FunctionTy: TypeRef) -> _c.uint ---
	GetParamTypes :: proc(FunctionTy: TypeRef, Dest: ^TypeRef) ---
	StructTypeInContext :: proc(C: ContextRef, ElementTypes: ^TypeRef, ElementCount: _c.uint, Packed: LLVMBool) -> TypeRef ---
	StructType :: proc(ElementTypes: ^TypeRef, ElementCount: _c.uint, Packed: LLVMBool) -> TypeRef ---
	StructCreateNamed :: proc(C: ContextRef, Name: cstring) -> TypeRef ---
	GetStructName :: proc(Ty: TypeRef) -> cstring ---
	StructSetBody :: proc(StructTy: TypeRef, ElementTypes: ^TypeRef, ElementCount: _c.uint, Packed: LLVMBool) ---
	CountStructElementTypes :: proc(StructTy: TypeRef) -> _c.uint ---
	GetStructElementTypes :: proc(StructTy: TypeRef, Dest: ^TypeRef) ---
	StructGetTypeAtIndex :: proc(StructTy: TypeRef, i: _c.uint) -> TypeRef ---
	IsPackedStruct :: proc(StructTy: TypeRef) -> LLVMBool ---
	IsOpaqueStruct :: proc(StructTy: TypeRef) -> LLVMBool ---
	IsLiteralStruct :: proc(StructTy: TypeRef) -> LLVMBool ---
	GetElementType :: proc(Ty: TypeRef) -> TypeRef ---
	GetSubtypes :: proc(Tp: TypeRef, Arr: ^TypeRef) ---
	GetNumContainedTypes :: proc(Tp: TypeRef) -> _c.uint ---
	ArrayType :: proc(ElementType: TypeRef, ElementCount: _c.uint) -> TypeRef ---
	ArrayType2 :: proc(ElementType: TypeRef, ElementCount: u64) -> TypeRef ---
	GetArrayLength :: proc(ArrayTy: TypeRef) -> _c.uint ---
	GetArrayLength2 :: proc(ArrayTy: TypeRef) -> u64 ---
	PointerType :: proc(ElementType: TypeRef, AddressSpace: _c.uint) -> TypeRef ---
	PointerTypeIsOpaque :: proc(Ty: TypeRef) -> LLVMBool ---
	PointerTypeInContext :: proc(C: ContextRef, AddressSpace: _c.uint) -> TypeRef ---
	GetPointerAddressSpace :: proc(PointerTy: TypeRef) -> _c.uint ---
	VectorType :: proc(ElementType: TypeRef, ElementCount: _c.uint) -> TypeRef ---
	ScalableVectorType :: proc(ElementType: TypeRef, ElementCount: _c.uint) -> TypeRef ---
	GetVectorSize :: proc(VectorTy: TypeRef) -> _c.uint ---
	VoidTypeInContext :: proc(C: ContextRef) -> TypeRef ---
	LabelTypeInContext :: proc(C: ContextRef) -> TypeRef ---
	X86MMXTypeInContext :: proc(C: ContextRef) -> TypeRef ---
	X86AMXTypeInContext :: proc(C: ContextRef) -> TypeRef ---
	TokenTypeInContext :: proc(C: ContextRef) -> TypeRef ---
	MetadataTypeInContext :: proc(C: ContextRef) -> TypeRef ---
	VoidType :: proc() -> TypeRef ---
	LabelType :: proc() -> TypeRef ---
	X86MMXType :: proc() -> TypeRef ---
	X86AMXType :: proc() -> TypeRef ---
	TargetExtTypeInContext :: proc(C: ContextRef, Name: cstring, TypeParams: ^TypeRef, TypeParamCount: _c.uint, IntParams: ^_c.uint, IntParamCount: _c.uint) -> TypeRef ---
	TypeOf :: proc(Val: ValueRef) -> TypeRef ---
	GetValueKind :: proc(Val: ValueRef) -> ValueKind ---
	GetValueName2 :: proc(Val: ValueRef, Length: ^_c.size_t) -> cstring ---
	SetValueName2 :: proc(Val: ValueRef, Name: cstring, NameLen: _c.size_t) ---
	DumpValue :: proc(Val: ValueRef) ---
	PrintValueToString :: proc(Val: ValueRef) -> cstring ---
	ReplaceAllUsesWith :: proc(OldVal: ValueRef, NewVal: ValueRef) ---
	IsConstant :: proc(Val: ValueRef) -> LLVMBool ---
	IsUndef :: proc(Val: ValueRef) -> LLVMBool ---
	IsPoison :: proc(Val: ValueRef) -> LLVMBool ---
	IsAMDNode :: proc(Val: ValueRef) -> ValueRef ---
	IsAValueAsMetadata :: proc(Val: ValueRef) -> ValueRef ---
	IsAMDString :: proc(Val: ValueRef) -> ValueRef ---
	GetValueName :: proc(Val: ValueRef) -> cstring ---
	SetValueName :: proc(Val: ValueRef, Name: cstring) ---
	GetFirstUse :: proc(Val: ValueRef) -> UseRef ---
	GetNextUse :: proc(U: UseRef) -> UseRef ---
	GetUser :: proc(U: UseRef) -> ValueRef ---
	GetUsedValue :: proc(U: UseRef) -> ValueRef ---
	GetOperand :: proc(Val: ValueRef, Index: _c.uint) -> ValueRef ---
	GetOperandUse :: proc(Val: ValueRef, Index: _c.uint) -> UseRef ---
	SetOperand :: proc(User: ValueRef, Index: _c.uint, Val: ValueRef) ---
	GetNumOperands :: proc(Val: ValueRef) -> _c.int ---
	ConstNull :: proc(Ty: TypeRef) -> ValueRef ---
	ConstAllOnes :: proc(Ty: TypeRef) -> ValueRef ---
	GetUndef :: proc(Ty: TypeRef) -> ValueRef ---
	GetPoison :: proc(Ty: TypeRef) -> ValueRef ---
	IsNull :: proc(Val: ValueRef) -> LLVMBool ---
	ConstPointerNull :: proc(Ty: TypeRef) -> ValueRef ---
	ConstInt :: proc(IntTy: TypeRef, N: _c.ulonglong, SignExtend: LLVMBool) -> ValueRef ---
	ConstIntOfArbitraryPrecision :: proc(IntTy: TypeRef, NumWords: _c.uint, Words: ^u64) -> ValueRef ---
	ConstIntOfString :: proc(IntTy: TypeRef, Text: cstring, Radix: u8) -> ValueRef ---
	ConstIntOfStringAndSize :: proc(IntTy: TypeRef, Text: cstring, SLen: _c.uint, Radix: u8) -> ValueRef ---
	ConstReal :: proc(RealTy: TypeRef, N: _c.double) -> ValueRef ---
	ConstRealOfString :: proc(RealTy: TypeRef, Text: cstring) -> ValueRef ---
	ConstRealOfStringAndSize :: proc(RealTy: TypeRef, Text: cstring, SLen: _c.uint) -> ValueRef ---
	ConstIntGetZExtValue :: proc(ConstantVal: ValueRef) -> _c.ulonglong ---
	ConstIntGetSExtValue :: proc(ConstantVal: ValueRef) -> _c.longlong ---
	ConstRealGetDouble :: proc(ConstantVal: ValueRef, losesInfo: ^LLVMBool) -> _c.double ---
	ConstStringInContext :: proc(C: ContextRef, Str: cstring, Length: _c.uint, DontNullTerminate: LLVMBool) -> ValueRef ---
	ConstString :: proc(Str: cstring, Length: _c.uint, DontNullTerminate: LLVMBool) -> ValueRef ---
	IsConstantString :: proc(c: ValueRef) -> LLVMBool ---
	GetAsString :: proc(c: ValueRef, Length: ^_c.size_t) -> cstring ---
	ConstStructInContext :: proc(C: ContextRef, ConstantVals: ^ValueRef, Count: _c.uint, Packed: LLVMBool) -> ValueRef ---
	ConstStruct :: proc(ConstantVals: ^ValueRef, Count: _c.uint, Packed: LLVMBool) -> ValueRef ---
	ConstArray :: proc(ElementTy: TypeRef, ConstantVals: ^ValueRef, Length: _c.uint) -> ValueRef ---
	ConstArray2 :: proc(ElementTy: TypeRef, ConstantVals: ^ValueRef, Length: u64) -> ValueRef ---
	ConstNamedStruct :: proc(StructTy: TypeRef, ConstantVals: ^ValueRef, Count: _c.uint) -> ValueRef ---
	GetAggregateElement :: proc(C: ValueRef, Idx: _c.uint) -> ValueRef ---
	ConstVector :: proc(ScalarConstantVals: ^ValueRef, Size: _c.uint) -> ValueRef ---
	GetConstOpcode :: proc(ConstantVal: ValueRef) -> Opcode ---
	AlignOf :: proc(Ty: TypeRef) -> ValueRef ---
	SizeOf :: proc(Ty: TypeRef) -> ValueRef ---
	ConstNeg :: proc(ConstantVal: ValueRef) -> ValueRef ---
	ConstNSWNeg :: proc(ConstantVal: ValueRef) -> ValueRef ---
	ConstNUWNeg :: proc(ConstantVal: ValueRef) -> ValueRef ---
	ConstNot :: proc(ConstantVal: ValueRef) -> ValueRef ---
	ConstAdd :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstNSWAdd :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstNUWAdd :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstSub :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstNSWSub :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstNUWSub :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstMul :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstNSWMul :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstNUWMul :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstAnd :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstOr :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstXor :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstICmp :: proc(Predicate: IntPredicate, LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstFCmp :: proc(Predicate: RealPredicate, LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstShl :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstLShr :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstAShr :: proc(LHSConstant: ValueRef, RHSConstant: ValueRef) -> ValueRef ---
	ConstGEP2 :: proc(Ty: TypeRef, ConstantVal: ValueRef, ConstantIndices: ^ValueRef, NumIndices: _c.uint) -> ValueRef ---
	ConstInBoundsGEP2 :: proc(Ty: TypeRef, ConstantVal: ValueRef, ConstantIndices: ^ValueRef, NumIndices: _c.uint) -> ValueRef ---
	ConstTrunc :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstSExt :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstZExt :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstFPTrunc :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstFPExt :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstUIToFP :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstSIToFP :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstFPToUI :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstFPToSI :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstPtrToInt :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstIntToPtr :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstBitCast :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstAddrSpaceCast :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstZExtOrBitCast :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstSExtOrBitCast :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstTruncOrBitCast :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstPointerCast :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstIntCast :: proc(ConstantVal: ValueRef, ToType: TypeRef, isSigned: LLVMBool) -> ValueRef ---
	ConstFPCast :: proc(ConstantVal: ValueRef, ToType: TypeRef) -> ValueRef ---
	ConstExtractElement :: proc(VectorConstant: ValueRef, IndexConstant: ValueRef) -> ValueRef ---
	ConstInsertElement :: proc(VectorConstant: ValueRef, ElementValueConstant: ValueRef, IndexConstant: ValueRef) -> ValueRef ---
	ConstShuffleVector :: proc(VectorAConstant: ValueRef, VectorBConstant: ValueRef, MaskConstant: ValueRef) -> ValueRef ---
	BlockAddress :: proc(F: ValueRef, BB: BasicBlockRef) -> ValueRef ---
	ConstInlineAsm :: proc(Ty: TypeRef, AsmString: cstring, Constraints: cstring, HasSideEffects: LLVMBool, IsAlignStack: LLVMBool) -> ValueRef ---
	GetGlobalParent :: proc(Global: ValueRef) -> ModuleRef ---
	IsDeclaration :: proc(Global: ValueRef) -> LLVMBool ---
	GetLinkage :: proc(Global: ValueRef) -> Linkage ---
	SetLinkage :: proc(Global: ValueRef, Linkage: Linkage) ---
	GetSection :: proc(Global: ValueRef) -> cstring ---
	SetSection :: proc(Global: ValueRef, Section: cstring) ---
	GetVisibility :: proc(Global: ValueRef) -> Visibility ---
	SetVisibility :: proc(Global: ValueRef, Viz: Visibility) ---
	GetDLLStorageClass :: proc(Global: ValueRef) -> DLLStorageClass ---
	SetDLLStorageClass :: proc(Global: ValueRef, Class: DLLStorageClass) ---
	GetUnnamedAddress :: proc(Global: ValueRef) -> UnnamedAddr ---
	SetUnnamedAddress :: proc(Global: ValueRef, UnnamedAddr: UnnamedAddr) ---
	GlobalGetValueType :: proc(Global: ValueRef) -> TypeRef ---
	HasUnnamedAddr :: proc(Global: ValueRef) -> LLVMBool ---
	SetUnnamedAddr :: proc(Global: ValueRef, HasUnnamedAddr: LLVMBool) ---
	GetAlignment :: proc(V: ValueRef) -> _c.uint ---
	SetAlignment :: proc(V: ValueRef, Bytes: _c.uint) ---
	GlobalSetMetadata :: proc(Global: ValueRef, Kind: _c.uint, MD: MetadataRef) ---
	GlobalEraseMetadata :: proc(Global: ValueRef, Kind: _c.uint) ---
	GlobalClearMetadata :: proc(Global: ValueRef) ---
	GlobalCopyAllMetadata :: proc(Value: ValueRef, NumEntries: ^_c.size_t) -> ^ValueMetadataEntry ---
	DisposeValueMetadataEntries :: proc(Entries: ^ValueMetadataEntry) ---
	ValueMetadataEntriesGetKind :: proc(Entries: ^ValueMetadataEntry, Index: _c.uint) -> _c.uint ---
	ValueMetadataEntriesGetMetadata :: proc(Entries: ^ValueMetadataEntry, Index: _c.uint) -> MetadataRef ---
	AddGlobal :: proc(M: ModuleRef, Ty: TypeRef, Name: cstring) -> ValueRef ---
	AddGlobalInAddressSpace :: proc(M: ModuleRef, Ty: TypeRef, Name: cstring, AddressSpace: _c.uint) -> ValueRef ---
	GetNamedGlobal :: proc(M: ModuleRef, Name: cstring) -> ValueRef ---
	GetFirstGlobal :: proc(M: ModuleRef) -> ValueRef ---
	GetLastGlobal :: proc(M: ModuleRef) -> ValueRef ---
	GetNextGlobal :: proc(GlobalVar: ValueRef) -> ValueRef ---
	GetPreviousGlobal :: proc(GlobalVar: ValueRef) -> ValueRef ---
	DeleteGlobal :: proc(GlobalVar: ValueRef) ---
	GetInitializer :: proc(GlobalVar: ValueRef) -> ValueRef ---
	SetInitializer :: proc(GlobalVar: ValueRef, ConstantVal: ValueRef) ---
	IsThreadLocal :: proc(GlobalVar: ValueRef) -> LLVMBool ---
	SetThreadLocal :: proc(GlobalVar: ValueRef, IsThreadLocal: LLVMBool) ---
	IsGlobalConstant :: proc(GlobalVar: ValueRef) -> LLVMBool ---
	SetGlobalConstant :: proc(GlobalVar: ValueRef, IsConstant: LLVMBool) ---
	GetThreadLocalMode :: proc(GlobalVar: ValueRef) -> ThreadLocalMode ---
	SetThreadLocalMode :: proc(GlobalVar: ValueRef, Mode: ThreadLocalMode) ---
	IsExternallyInitialized :: proc(GlobalVar: ValueRef) -> LLVMBool ---
	SetExternallyInitialized :: proc(GlobalVar: ValueRef, IsExtInit: LLVMBool) ---
	AddAlias2 :: proc(M: ModuleRef, ValueTy: TypeRef, AddrSpace: _c.uint, Aliasee: ValueRef, Name: cstring) -> ValueRef ---
	GetNamedGlobalAlias :: proc(M: ModuleRef, Name: cstring, NameLen: _c.size_t) -> ValueRef ---
	GetFirstGlobalAlias :: proc(M: ModuleRef) -> ValueRef ---
	GetLastGlobalAlias :: proc(M: ModuleRef) -> ValueRef ---
	GetNextGlobalAlias :: proc(GA: ValueRef) -> ValueRef ---
	GetPreviousGlobalAlias :: proc(GA: ValueRef) -> ValueRef ---
	AliasGetAliasee :: proc(Alias: ValueRef) -> ValueRef ---
	AliasSetAliasee :: proc(Alias: ValueRef, Aliasee: ValueRef) ---
	DeleteFunction :: proc(Fn: ValueRef) ---
	HasPersonalityFn :: proc(Fn: ValueRef) -> LLVMBool ---
	GetPersonalityFn :: proc(Fn: ValueRef) -> ValueRef ---
	SetPersonalityFn :: proc(Fn: ValueRef, PersonalityFn: ValueRef) ---
	LookupIntrinsicID :: proc(Name: cstring, NameLen: _c.size_t) -> _c.uint ---
	GetIntrinsicID :: proc(Fn: ValueRef) -> _c.uint ---
	GetIntrinsicDeclaration :: proc(Mod: ModuleRef, ID: _c.uint, ParamTypes: ^TypeRef, ParamCount: _c.size_t) -> ValueRef ---
	IntrinsicGetType :: proc(Ctx: ContextRef, ID: _c.uint, ParamTypes: ^TypeRef, ParamCount: _c.size_t) -> TypeRef ---
	IntrinsicGetName :: proc(ID: _c.uint, NameLength: ^_c.size_t) -> cstring ---
	IntrinsicCopyOverloadedName :: proc(ID: _c.uint, ParamTypes: ^TypeRef, ParamCount: _c.size_t, NameLength: ^_c.size_t) -> cstring ---
	IntrinsicCopyOverloadedName2 :: proc(Mod: ModuleRef, ID: _c.uint, ParamTypes: ^TypeRef, ParamCount: _c.size_t, NameLength: ^_c.size_t) -> cstring ---
	IntrinsicIsOverloaded :: proc(ID: _c.uint) -> LLVMBool ---
	GetFunctionCallConv :: proc(Fn: ValueRef) -> _c.uint ---
	SetFunctionCallConv :: proc(Fn: ValueRef, CC: _c.uint) ---
	GetGC :: proc(Fn: ValueRef) -> cstring ---
	SetGC :: proc(Fn: ValueRef, Name: cstring) ---
	AddAttributeAtIndex :: proc(F: ValueRef, Idx: _c.uint, A: AttributeRef) ---
	GetAttributeCountAtIndex :: proc(F: ValueRef, Idx: _c.uint) -> _c.uint ---
	GetAttributesAtIndex :: proc(F: ValueRef, Idx: _c.uint, Attrs: ^AttributeRef) ---
	GetEnumAttributeAtIndex :: proc(F: ValueRef, Idx: _c.uint, KindID: _c.uint) -> AttributeRef ---
	GetStringAttributeAtIndex :: proc(F: ValueRef, Idx: _c.uint, K: cstring, KLen: _c.uint) -> AttributeRef ---
	RemoveEnumAttributeAtIndex :: proc(F: ValueRef, Idx: _c.uint, KindID: _c.uint) ---
	RemoveStringAttributeAtIndex :: proc(F: ValueRef, Idx: _c.uint, K: cstring, KLen: _c.uint) ---
	AddTargetDependentFunctionAttr :: proc(Fn: ValueRef, A: cstring, V: cstring) ---
	CountParams :: proc(Fn: ValueRef) -> _c.uint ---
	GetParams :: proc(Fn: ValueRef, Params: ^ValueRef) ---
	GetParam :: proc(Fn: ValueRef, Index: _c.uint) -> ValueRef ---
	GetParamParent :: proc(Inst: ValueRef) -> ValueRef ---
	GetFirstParam :: proc(Fn: ValueRef) -> ValueRef ---
	GetLastParam :: proc(Fn: ValueRef) -> ValueRef ---
	GetNextParam :: proc(Arg: ValueRef) -> ValueRef ---
	GetPreviousParam :: proc(Arg: ValueRef) -> ValueRef ---
	SetParamAlignment :: proc(Arg: ValueRef, Align: _c.uint) ---
	AddGlobalIFunc :: proc(M: ModuleRef, Name: cstring, NameLen: _c.size_t, Ty: TypeRef, AddrSpace: _c.uint, Resolver: ValueRef) -> ValueRef ---
	GetNamedGlobalIFunc :: proc(M: ModuleRef, Name: cstring, NameLen: _c.size_t) -> ValueRef ---
	GetFirstGlobalIFunc :: proc(M: ModuleRef) -> ValueRef ---
	GetLastGlobalIFunc :: proc(M: ModuleRef) -> ValueRef ---
	GetNextGlobalIFunc :: proc(IFunc: ValueRef) -> ValueRef ---
	GetPreviousGlobalIFunc :: proc(IFunc: ValueRef) -> ValueRef ---
	GetGlobalIFuncResolver :: proc(IFunc: ValueRef) -> ValueRef ---
	SetGlobalIFuncResolver :: proc(IFunc: ValueRef, Resolver: ValueRef) ---
	EraseGlobalIFunc :: proc(IFunc: ValueRef) ---
	RemoveGlobalIFunc :: proc(IFunc: ValueRef) ---
	MDStringInContext2 :: proc(C: ContextRef, Str: cstring, SLen: _c.size_t) -> MetadataRef ---
	MDNodeInContext2 :: proc(C: ContextRef, MDs: ^MetadataRef, Count: _c.size_t) -> MetadataRef ---
	MetadataAsValue :: proc(C: ContextRef, MD: MetadataRef) -> ValueRef ---
	ValueAsMetadata :: proc(Val: ValueRef) -> MetadataRef ---
	GetMDString :: proc(V: ValueRef, Length: ^_c.uint) -> cstring ---
	GetMDNodeNumOperands :: proc(V: ValueRef) -> _c.uint ---
	GetMDNodeOperands :: proc(V: ValueRef, Dest: ^ValueRef) ---
	ReplaceMDNodeOperandWith :: proc(V: ValueRef, Index: _c.uint, Replacement: MetadataRef) ---
	MDStringInContext :: proc(C: ContextRef, Str: cstring, SLen: _c.uint) -> ValueRef ---
	MDString :: proc(Str: cstring, SLen: _c.uint) -> ValueRef ---
	MDNodeInContext :: proc(C: ContextRef, Vals: ^ValueRef, Count: _c.uint) -> ValueRef ---
	MDNode :: proc(Vals: ^ValueRef, Count: _c.uint) -> ValueRef ---
	BasicBlockAsValue :: proc(BB: BasicBlockRef) -> ValueRef ---
	ValueIsBasicBlock :: proc(Val: ValueRef) -> LLVMBool ---
	ValueAsBasicBlock :: proc(Val: ValueRef) -> BasicBlockRef ---
	GetBasicBlockName :: proc(BB: BasicBlockRef) -> cstring ---
	GetBasicBlockParent :: proc(BB: BasicBlockRef) -> ValueRef ---
	GetBasicBlockTerminator :: proc(BB: BasicBlockRef) -> ValueRef ---
	CountBasicBlocks :: proc(Fn: ValueRef) -> _c.uint ---
	GetBasicBlocks :: proc(Fn: ValueRef, BasicBlocks: ^BasicBlockRef) ---
	GetFirstBasicBlock :: proc(Fn: ValueRef) -> BasicBlockRef ---
	GetLastBasicBlock :: proc(Fn: ValueRef) -> BasicBlockRef ---
	GetNextBasicBlock :: proc(BB: BasicBlockRef) -> BasicBlockRef ---
	GetPreviousBasicBlock :: proc(BB: BasicBlockRef) -> BasicBlockRef ---
	GetEntryBasicBlock :: proc(Fn: ValueRef) -> BasicBlockRef ---
	InsertExistingBasicBlockAfterInsertBlock :: proc(Builder: BuilderRef, BB: BasicBlockRef) ---
	AppendExistingBasicBlock :: proc(Fn: ValueRef, BB: BasicBlockRef) ---
	CreateBasicBlockInContext :: proc(C: ContextRef, Name: cstring) -> BasicBlockRef ---
	AppendBasicBlockInContext :: proc(C: ContextRef, Fn: ValueRef, Name: cstring) -> BasicBlockRef ---
	AppendBasicBlock :: proc(Fn: ValueRef, Name: cstring) -> BasicBlockRef ---
	InsertBasicBlockInContext :: proc(C: ContextRef, BB: BasicBlockRef, Name: cstring) -> BasicBlockRef ---
	InsertBasicBlock :: proc(InsertBeforeBB: BasicBlockRef, Name: cstring) -> BasicBlockRef ---
	DeleteBasicBlock :: proc(BB: BasicBlockRef) ---
	RemoveBasicBlockFromParent :: proc(BB: BasicBlockRef) ---
	MoveBasicBlockBefore :: proc(BB: BasicBlockRef, MovePos: BasicBlockRef) ---
	MoveBasicBlockAfter :: proc(BB: BasicBlockRef, MovePos: BasicBlockRef) ---
	GetFirstInstruction :: proc(BB: BasicBlockRef) -> ValueRef ---
	GetLastInstruction :: proc(BB: BasicBlockRef) -> ValueRef ---
	HasMetadata :: proc(Val: ValueRef) -> _c.int ---
	GetMetadata :: proc(Val: ValueRef, KindID: _c.uint) -> ValueRef ---
	SetMetadata :: proc(Val: ValueRef, KindID: _c.uint, Node: ValueRef) ---
	InstructionGetAllMetadataOtherThanDebugLoc :: proc(Instr: ValueRef, NumEntries: ^_c.size_t) -> ^ValueMetadataEntry ---
	GetInstructionParent :: proc(Inst: ValueRef) -> BasicBlockRef ---
	GetNextInstruction :: proc(Inst: ValueRef) -> ValueRef ---
	GetPreviousInstruction :: proc(Inst: ValueRef) -> ValueRef ---
	InstructionRemoveFromParent :: proc(Inst: ValueRef) ---
	InstructionEraseFromParent :: proc(Inst: ValueRef) ---
	DeleteInstruction :: proc(Inst: ValueRef) ---
	GetInstructionOpcode :: proc(Inst: ValueRef) -> Opcode ---
	GetICmpPredicate :: proc(Inst: ValueRef) -> IntPredicate ---
	GetFCmpPredicate :: proc(Inst: ValueRef) -> RealPredicate ---
	InstructionClone :: proc(Inst: ValueRef) -> ValueRef ---
	IsATerminatorInst :: proc(Inst: ValueRef) -> ValueRef ---
	GetNumArgOperands :: proc(Instr: ValueRef) -> _c.uint ---
	SetInstructionCallConv :: proc(Instr: ValueRef, CC: _c.uint) ---
	GetInstructionCallConv :: proc(Instr: ValueRef) -> _c.uint ---
	SetInstrParamAlignment :: proc(Instr: ValueRef, Idx: _c.uint, Align: _c.uint) ---
	AddCallSiteAttribute :: proc(C: ValueRef, Idx: _c.uint, A: AttributeRef) ---
	GetCallSiteAttributeCount :: proc(C: ValueRef, Idx: _c.uint) -> _c.uint ---
	GetCallSiteAttributes :: proc(C: ValueRef, Idx: _c.uint, Attrs: ^AttributeRef) ---
	GetCallSiteEnumAttribute :: proc(C: ValueRef, Idx: _c.uint, KindID: _c.uint) -> AttributeRef ---
	GetCallSiteStringAttribute :: proc(C: ValueRef, Idx: _c.uint, K: cstring, KLen: _c.uint) -> AttributeRef ---
	RemoveCallSiteEnumAttribute :: proc(C: ValueRef, Idx: _c.uint, KindID: _c.uint) ---
	RemoveCallSiteStringAttribute :: proc(C: ValueRef, Idx: _c.uint, K: cstring, KLen: _c.uint) ---
	GetCalledFunctionType :: proc(C: ValueRef) -> TypeRef ---
	GetCalledValue :: proc(Instr: ValueRef) -> ValueRef ---
	IsTailCall :: proc(CallInst: ValueRef) -> LLVMBool ---
	SetTailCall :: proc(CallInst: ValueRef, IsTailCall: LLVMBool) ---
	GetNormalDest :: proc(InvokeInst: ValueRef) -> BasicBlockRef ---
	GetUnwindDest :: proc(InvokeInst: ValueRef) -> BasicBlockRef ---
	SetNormalDest :: proc(InvokeInst: ValueRef, B: BasicBlockRef) ---
	SetUnwindDest :: proc(InvokeInst: ValueRef, B: BasicBlockRef) ---
	GetNumSuccessors :: proc(Term: ValueRef) -> _c.uint ---
	GetSuccessor :: proc(Term: ValueRef, i: _c.uint) -> BasicBlockRef ---
	SetSuccessor :: proc(Term: ValueRef, i: _c.uint, block: BasicBlockRef) ---
	IsConditional :: proc(Branch: ValueRef) -> LLVMBool ---
	GetCondition :: proc(Branch: ValueRef) -> ValueRef ---
	SetCondition :: proc(Branch: ValueRef, Cond: ValueRef) ---
	GetSwitchDefaultDest :: proc(SwitchInstr: ValueRef) -> BasicBlockRef ---
	GetAllocatedType :: proc(Alloca: ValueRef) -> TypeRef ---
	IsInBounds :: proc(GEP: ValueRef) -> LLVMBool ---
	SetIsInBounds :: proc(GEP: ValueRef, InBounds: LLVMBool) ---
	GetGEPSourceElementType :: proc(GEP: ValueRef) -> TypeRef ---
	AddIncoming :: proc(PhiNode: ValueRef, IncomingValues: ^ValueRef, IncomingBlocks: ^BasicBlockRef, Count: _c.uint) ---
	CountIncoming :: proc(PhiNode: ValueRef) -> _c.uint ---
	GetIncomingValue :: proc(PhiNode: ValueRef, Index: _c.uint) -> ValueRef ---
	GetIncomingBlock :: proc(PhiNode: ValueRef, Index: _c.uint) -> BasicBlockRef ---
	GetNumIndices :: proc(Inst: ValueRef) -> _c.uint ---
	GetIndices :: proc(Inst: ValueRef) -> ^_c.uint ---
	CreateBuilderInContext :: proc(C: ContextRef) -> BuilderRef ---
	CreateBuilder :: proc() -> BuilderRef ---
	PositionBuilder :: proc(Builder: BuilderRef, Block: BasicBlockRef, Instr: ValueRef) ---
	PositionBuilderBefore :: proc(Builder: BuilderRef, Instr: ValueRef) ---
	PositionBuilderAtEnd :: proc(Builder: BuilderRef, Block: BasicBlockRef) ---
	GetInsertBlock :: proc(Builder: BuilderRef) -> BasicBlockRef ---
	ClearInsertionPosition :: proc(Builder: BuilderRef) ---
	InsertIntoBuilder :: proc(Builder: BuilderRef, Instr: ValueRef) ---
	InsertIntoBuilderWithName :: proc(Builder: BuilderRef, Instr: ValueRef, Name: cstring) ---
	DisposeBuilder :: proc(Builder: BuilderRef) ---
	GetCurrentDebugLocation2 :: proc(Builder: BuilderRef) -> MetadataRef ---
	SetCurrentDebugLocation2 :: proc(Builder: BuilderRef, Loc: MetadataRef) ---
	SetInstDebugLocation :: proc(Builder: BuilderRef, Inst: ValueRef) ---
	AddMetadataToInst :: proc(Builder: BuilderRef, Inst: ValueRef) ---
	BuilderGetDefaultFPMathTag :: proc(Builder: BuilderRef) -> MetadataRef ---
	BuilderSetDefaultFPMathTag :: proc(Builder: BuilderRef, FPMathTag: MetadataRef) ---
	SetCurrentDebugLocation :: proc(Builder: BuilderRef, L: ValueRef) ---
	GetCurrentDebugLocation :: proc(Builder: BuilderRef) -> ValueRef ---
	BuildRetVoid :: proc(unamed0: BuilderRef) -> ValueRef ---
	BuildRet :: proc(unamed0: BuilderRef, V: ValueRef) -> ValueRef ---
	BuildAggregateRet :: proc(unamed0: BuilderRef, RetVals: ^ValueRef, N: _c.uint) -> ValueRef ---
	BuildBr :: proc(unamed0: BuilderRef, Dest: BasicBlockRef) -> ValueRef ---
	BuildCondBr :: proc(unamed0: BuilderRef, If: ValueRef, Then: BasicBlockRef, Else: BasicBlockRef) -> ValueRef ---
	BuildSwitch :: proc(unamed0: BuilderRef, V: ValueRef, Else: BasicBlockRef, NumCases: _c.uint) -> ValueRef ---
	BuildIndirectBr :: proc(B: BuilderRef, Addr: ValueRef, NumDests: _c.uint) -> ValueRef ---
	BuildInvoke2 :: proc(unamed0: BuilderRef, Ty: TypeRef, Fn: ValueRef, Args: ^ValueRef, NumArgs: _c.uint, Then: BasicBlockRef, Catch: BasicBlockRef, Name: cstring) -> ValueRef ---
	BuildUnreachable :: proc(unamed0: BuilderRef) -> ValueRef ---
	BuildResume :: proc(B: BuilderRef, Exn: ValueRef) -> ValueRef ---
	BuildLandingPad :: proc(B: BuilderRef, Ty: TypeRef, PersFn: ValueRef, NumClauses: _c.uint, Name: cstring) -> ValueRef ---
	BuildCleanupRet :: proc(B: BuilderRef, CatchPad: ValueRef, BB: BasicBlockRef) -> ValueRef ---
	BuildCatchRet :: proc(B: BuilderRef, CatchPad: ValueRef, BB: BasicBlockRef) -> ValueRef ---
	BuildCatchPad :: proc(B: BuilderRef, ParentPad: ValueRef, Args: ^ValueRef, NumArgs: _c.uint, Name: cstring) -> ValueRef ---
	BuildCleanupPad :: proc(B: BuilderRef, ParentPad: ValueRef, Args: ^ValueRef, NumArgs: _c.uint, Name: cstring) -> ValueRef ---
	BuildCatchSwitch :: proc(B: BuilderRef, ParentPad: ValueRef, UnwindBB: BasicBlockRef, NumHandlers: _c.uint, Name: cstring) -> ValueRef ---
	AddCase :: proc(Switch: ValueRef, OnVal: ValueRef, Dest: BasicBlockRef) ---
	AddDestination :: proc(IndirectBr: ValueRef, Dest: BasicBlockRef) ---
	GetNumClauses :: proc(LandingPad: ValueRef) -> _c.uint ---
	GetClause :: proc(LandingPad: ValueRef, Idx: _c.uint) -> ValueRef ---
	AddClause :: proc(LandingPad: ValueRef, ClauseVal: ValueRef) ---
	IsCleanup :: proc(LandingPad: ValueRef) -> LLVMBool ---
	SetCleanup :: proc(LandingPad: ValueRef, Val: LLVMBool) ---
	AddHandler :: proc(CatchSwitch: ValueRef, Dest: BasicBlockRef) ---
	GetNumHandlers :: proc(CatchSwitch: ValueRef) -> _c.uint ---
	GetHandlers :: proc(CatchSwitch: ValueRef, Handlers: ^BasicBlockRef) ---
	GetArgOperand :: proc(Funclet: ValueRef, i: _c.uint) -> ValueRef ---
	SetArgOperand :: proc(Funclet: ValueRef, i: _c.uint, value: ValueRef) ---
	GetParentCatchSwitch :: proc(CatchPad: ValueRef) -> ValueRef ---
	SetParentCatchSwitch :: proc(CatchPad: ValueRef, CatchSwitch: ValueRef) ---
	BuildAdd :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildNSWAdd :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildNUWAdd :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildFAdd :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildSub :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildNSWSub :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildNUWSub :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildFSub :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildMul :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildNSWMul :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildNUWMul :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildFMul :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildUDiv :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildExactUDiv :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildSDiv :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildExactSDiv :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildFDiv :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildURem :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildSRem :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildFRem :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildShl :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildLShr :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildAShr :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildAnd :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildOr :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildXor :: proc(unamed0: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildBinOp :: proc(B: BuilderRef, Op: Opcode, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildNeg :: proc(unamed0: BuilderRef, V: ValueRef, Name: cstring) -> ValueRef ---
	BuildNSWNeg :: proc(B: BuilderRef, V: ValueRef, Name: cstring) -> ValueRef ---
	BuildNUWNeg :: proc(B: BuilderRef, V: ValueRef, Name: cstring) -> ValueRef ---
	BuildFNeg :: proc(unamed0: BuilderRef, V: ValueRef, Name: cstring) -> ValueRef ---
	BuildNot :: proc(unamed0: BuilderRef, V: ValueRef, Name: cstring) -> ValueRef ---
	GetNUW :: proc(ArithInst: ValueRef) -> LLVMBool ---
	SetNUW :: proc(ArithInst: ValueRef, HasNUW: LLVMBool) ---
	GetNSW :: proc(ArithInst: ValueRef) -> LLVMBool ---
	SetNSW :: proc(ArithInst: ValueRef, HasNSW: LLVMBool) ---
	GetExact :: proc(DivOrShrInst: ValueRef) -> LLVMBool ---
	SetExact :: proc(DivOrShrInst: ValueRef, IsExact: LLVMBool) ---
	BuildMalloc :: proc(unamed0: BuilderRef, Ty: TypeRef, Name: cstring) -> ValueRef ---
	BuildArrayMalloc :: proc(unamed0: BuilderRef, Ty: TypeRef, Val: ValueRef, Name: cstring) -> ValueRef ---
	BuildMemSet :: proc(B: BuilderRef, Ptr: ValueRef, Val: ValueRef, Len: ValueRef, Align: _c.uint) -> ValueRef ---
	BuildMemCpy :: proc(B: BuilderRef, Dst: ValueRef, DstAlign: _c.uint, Src: ValueRef, SrcAlign: _c.uint, Size: ValueRef) -> ValueRef ---
	BuildMemMove :: proc(B: BuilderRef, Dst: ValueRef, DstAlign: _c.uint, Src: ValueRef, SrcAlign: _c.uint, Size: ValueRef) -> ValueRef ---
	BuildAlloca :: proc(unamed0: BuilderRef, Ty: TypeRef, Name: cstring) -> ValueRef ---
	BuildArrayAlloca :: proc(unamed0: BuilderRef, Ty: TypeRef, Val: ValueRef, Name: cstring) -> ValueRef ---
	BuildFree :: proc(unamed0: BuilderRef, PointerVal: ValueRef) -> ValueRef ---
	BuildLoad2 :: proc(unamed0: BuilderRef, Ty: TypeRef, PointerVal: ValueRef, Name: cstring) -> ValueRef ---
	BuildStore :: proc(unamed0: BuilderRef, Val: ValueRef, Ptr: ValueRef) -> ValueRef ---
	BuildGEP2 :: proc(B: BuilderRef, Ty: TypeRef, Pointer: ValueRef, Indices: ^ValueRef, NumIndices: _c.uint, Name: cstring) -> ValueRef ---
	BuildInBoundsGEP2 :: proc(B: BuilderRef, Ty: TypeRef, Pointer: ValueRef, Indices: ^ValueRef, NumIndices: _c.uint, Name: cstring) -> ValueRef ---
	BuildStructGEP2 :: proc(B: BuilderRef, Ty: TypeRef, Pointer: ValueRef, Idx: _c.uint, Name: cstring) -> ValueRef ---
	BuildGlobalString :: proc(B: BuilderRef, Str: cstring, Name: cstring) -> ValueRef ---
	BuildGlobalStringPtr :: proc(B: BuilderRef, Str: cstring, Name: cstring) -> ValueRef ---
	GetVolatile :: proc(MemoryAccessInst: ValueRef) -> LLVMBool ---
	SetVolatile :: proc(MemoryAccessInst: ValueRef, IsVolatile: LLVMBool) ---
	GetWeak :: proc(CmpXchgInst: ValueRef) -> LLVMBool ---
	SetWeak :: proc(CmpXchgInst: ValueRef, IsWeak: LLVMBool) ---
	GetOrdering :: proc(MemoryAccessInst: ValueRef) -> AtomicOrdering ---
	SetOrdering :: proc(MemoryAccessInst: ValueRef, Ordering: AtomicOrdering) ---
	GetAtomicRMWBinOp :: proc(AtomicRMWInst: ValueRef) -> AtomicRMWBinOp ---
	SetAtomicRMWBinOp :: proc(AtomicRMWInst: ValueRef, BinOp: AtomicRMWBinOp) ---
	BuildTrunc :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildZExt :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildSExt :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildFPToUI :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildFPToSI :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildUIToFP :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildSIToFP :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildFPTrunc :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildFPExt :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildPtrToInt :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildIntToPtr :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildBitCast :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildAddrSpaceCast :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildZExtOrBitCast :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildSExtOrBitCast :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildTruncOrBitCast :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildCast :: proc(B: BuilderRef, Op: Opcode, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildPointerCast :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildIntCast2 :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, IsSigned: LLVMBool, Name: cstring) -> ValueRef ---
	BuildFPCast :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	BuildIntCast :: proc(unamed0: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	GetCastOpcode :: proc(Src: ValueRef, SrcIsSigned: LLVMBool, DestTy: TypeRef, DestIsSigned: LLVMBool) -> Opcode ---
	BuildICmp :: proc(unamed0: BuilderRef, Op: IntPredicate, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildFCmp :: proc(unamed0: BuilderRef, Op: RealPredicate, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildPhi :: proc(unamed0: BuilderRef, Ty: TypeRef, Name: cstring) -> ValueRef ---
	BuildCall2 :: proc(unamed0: BuilderRef, unamed1: TypeRef, Fn: ValueRef, Args: ^ValueRef, NumArgs: _c.uint, Name: cstring) -> ValueRef ---
	BuildSelect :: proc(unamed0: BuilderRef, If: ValueRef, Then: ValueRef, Else: ValueRef, Name: cstring) -> ValueRef ---
	BuildVAArg :: proc(unamed0: BuilderRef, List: ValueRef, Ty: TypeRef, Name: cstring) -> ValueRef ---
	BuildExtractElement :: proc(unamed0: BuilderRef, VecVal: ValueRef, Index: ValueRef, Name: cstring) -> ValueRef ---
	BuildInsertElement :: proc(unamed0: BuilderRef, VecVal: ValueRef, EltVal: ValueRef, Index: ValueRef, Name: cstring) -> ValueRef ---
	BuildShuffleVector :: proc(unamed0: BuilderRef, V1: ValueRef, V2: ValueRef, Mask: ValueRef, Name: cstring) -> ValueRef ---
	BuildExtractValue :: proc(unamed0: BuilderRef, AggVal: ValueRef, Index: _c.uint, Name: cstring) -> ValueRef ---
	BuildInsertValue :: proc(unamed0: BuilderRef, AggVal: ValueRef, EltVal: ValueRef, Index: _c.uint, Name: cstring) -> ValueRef ---
	BuildFreeze :: proc(unamed0: BuilderRef, Val: ValueRef, Name: cstring) -> ValueRef ---
	BuildIsNull :: proc(unamed0: BuilderRef, Val: ValueRef, Name: cstring) -> ValueRef ---
	BuildIsNotNull :: proc(unamed0: BuilderRef, Val: ValueRef, Name: cstring) -> ValueRef ---
	BuildPtrDiff2 :: proc(unamed0: BuilderRef, ElemTy: TypeRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	BuildFence :: proc(B: BuilderRef, ordering: AtomicOrdering, singleThread: LLVMBool, Name: cstring) -> ValueRef ---
	BuildAtomicRMW :: proc(B: BuilderRef, op: AtomicRMWBinOp, PTR: ValueRef, Val: ValueRef, ordering: AtomicOrdering, singleThread: LLVMBool) -> ValueRef ---
	BuildAtomicCmpXchg :: proc(B: BuilderRef, Ptr: ValueRef, Cmp: ValueRef, New: ValueRef, SuccessOrdering: AtomicOrdering, FailureOrdering: AtomicOrdering, SingleThread: LLVMBool) -> ValueRef ---
	GetNumMaskElements :: proc(ShuffleVectorInst: ValueRef) -> _c.uint ---
	GetUndefMaskElem :: proc() -> _c.int ---
	GetMaskValue :: proc(ShuffleVectorInst: ValueRef, Elt: _c.uint) -> _c.int ---
	IsAtomicSingleThread :: proc(AtomicInst: ValueRef) -> LLVMBool ---
	SetAtomicSingleThread :: proc(AtomicInst: ValueRef, SingleThread: LLVMBool) ---
	GetCmpXchgSuccessOrdering :: proc(CmpXchgInst: ValueRef) -> AtomicOrdering ---
	SetCmpXchgSuccessOrdering :: proc(CmpXchgInst: ValueRef, Ordering: AtomicOrdering) ---
	GetCmpXchgFailureOrdering :: proc(CmpXchgInst: ValueRef) -> AtomicOrdering ---
	SetCmpXchgFailureOrdering :: proc(CmpXchgInst: ValueRef, Ordering: AtomicOrdering) ---
	CreateModuleProviderForExistingModule :: proc(M: ModuleRef) -> ModuleProviderRef ---
	DisposeModuleProvider :: proc(M: ModuleProviderRef) ---
	CreateMemoryBufferWithContentsOfFile :: proc(Path: cstring, OutMemBuf: ^MemoryBufferRef, OutMessage: ^cstring) -> LLVMBool ---
	CreateMemoryBufferWithSTDIN :: proc(OutMemBuf: ^MemoryBufferRef, OutMessage: ^cstring) -> LLVMBool ---
	CreateMemoryBufferWithMemoryRange :: proc(InputData: cstring, InputDataLength: _c.size_t, BufferName: cstring, RequiresNullTerminator: LLVMBool) -> MemoryBufferRef ---
	CreateMemoryBufferWithMemoryRangeCopy :: proc(InputData: cstring, InputDataLength: _c.size_t, BufferName: cstring) -> MemoryBufferRef ---
	GetBufferStart :: proc(MemBuf: MemoryBufferRef) -> cstring ---
	GetBufferSize :: proc(MemBuf: MemoryBufferRef) -> _c.size_t ---
	DisposeMemoryBuffer :: proc(MemBuf: MemoryBufferRef) ---
	CreatePassManager :: proc() -> PassManagerRef ---
	CreateFunctionPassManagerForModule :: proc(M: ModuleRef) -> PassManagerRef ---
	CreateFunctionPassManager :: proc(MP: ModuleProviderRef) -> PassManagerRef ---
	RunPassManager :: proc(PM: PassManagerRef, M: ModuleRef) -> LLVMBool ---
	InitializeFunctionPassManager :: proc(FPM: PassManagerRef) -> LLVMBool ---
	RunFunctionPassManager :: proc(FPM: PassManagerRef, F: ValueRef) -> LLVMBool ---
	FinalizeFunctionPassManager :: proc(FPM: PassManagerRef) -> LLVMBool ---
	DisposePassManager :: proc(PM: PassManagerRef) ---
	StartMultithreaded :: proc() -> LLVMBool ---
	StopMultithreaded :: proc() ---
	IsMultithreaded :: proc() -> LLVMBool ---
	DebugMetadataVersion :: proc() -> _c.uint ---
	GetModuleDebugMetadataVersion :: proc(Module: ModuleRef) -> _c.uint ---
	StripModuleDebugInfo :: proc(Module: ModuleRef) -> LLVMBool ---
	CreateDIBuilderDisallowUnresolved :: proc(M: ModuleRef) -> DIBuilderRef ---
	CreateDIBuilder :: proc(M: ModuleRef) -> DIBuilderRef ---
	DisposeDIBuilder :: proc(Builder: DIBuilderRef) ---
	DIBuilderFinalize :: proc(Builder: DIBuilderRef) ---
	DIBuilderFinalizeSubprogram :: proc(Builder: DIBuilderRef, Subprogram: MetadataRef) ---
	DIBuilderCreateCompileUnit :: proc(Builder: DIBuilderRef, Lang: DWARFSourceLanguage, FileRef: MetadataRef, Producer: cstring, ProducerLen: _c.size_t, isOptimized: LLVMBool, Flags: cstring, FlagsLen: _c.size_t, RuntimeVer: _c.uint, SplitName: cstring, SplitNameLen: _c.size_t, Kind: DWARFEmissionKind, DWOId: _c.uint, SplitDebugInlining: LLVMBool, DebugInfoForProfiling: LLVMBool, SysRoot: cstring, SysRootLen: _c.size_t, SDK: cstring, SDKLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateFile :: proc(Builder: DIBuilderRef, Filename: cstring, FilenameLen: _c.size_t, Directory: cstring, DirectoryLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateModule :: proc(Builder: DIBuilderRef, ParentScope: MetadataRef, Name: cstring, NameLen: _c.size_t, ConfigMacros: cstring, ConfigMacrosLen: _c.size_t, IncludePath: cstring, IncludePathLen: _c.size_t, APINotesFile: cstring, APINotesFileLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateNameSpace :: proc(Builder: DIBuilderRef, ParentScope: MetadataRef, Name: cstring, NameLen: _c.size_t, ExportSymbols: LLVMBool) -> MetadataRef ---
	DIBuilderCreateFunction :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, LinkageName: cstring, LinkageNameLen: _c.size_t, File: MetadataRef, LineNo: _c.uint, Ty: MetadataRef, IsLocalToUnit: LLVMBool, IsDefinition: LLVMBool, ScopeLine: _c.uint, Flags: DIFlags, IsOptimized: LLVMBool) -> MetadataRef ---
	DIBuilderCreateLexicalBlock :: proc(Builder: DIBuilderRef, Scope: MetadataRef, File: MetadataRef, Line: _c.uint, Column: _c.uint) -> MetadataRef ---
	DIBuilderCreateLexicalBlockFile :: proc(Builder: DIBuilderRef, Scope: MetadataRef, File: MetadataRef, Discriminator: _c.uint) -> MetadataRef ---
	DIBuilderCreateImportedModuleFromNamespace :: proc(Builder: DIBuilderRef, Scope: MetadataRef, NS: MetadataRef, File: MetadataRef, Line: _c.uint) -> MetadataRef ---
	DIBuilderCreateImportedModuleFromAlias :: proc(Builder: DIBuilderRef, Scope: MetadataRef, ImportedEntity: MetadataRef, File: MetadataRef, Line: _c.uint, Elements: ^MetadataRef, NumElements: _c.uint) -> MetadataRef ---
	DIBuilderCreateImportedModuleFromModule :: proc(Builder: DIBuilderRef, Scope: MetadataRef, M: MetadataRef, File: MetadataRef, Line: _c.uint, Elements: ^MetadataRef, NumElements: _c.uint) -> MetadataRef ---
	DIBuilderCreateImportedDeclaration :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Decl: MetadataRef, File: MetadataRef, Line: _c.uint, Name: cstring, NameLen: _c.size_t, Elements: ^MetadataRef, NumElements: _c.uint) -> MetadataRef ---
	DIBuilderCreateDebugLocation :: proc(Ctx: ContextRef, Line: _c.uint, Column: _c.uint, Scope: MetadataRef, InlinedAt: MetadataRef) -> MetadataRef ---
	DILocationGetLine :: proc(Location: MetadataRef) -> _c.uint ---
	DILocationGetColumn :: proc(Location: MetadataRef) -> _c.uint ---
	DILocationGetScope :: proc(Location: MetadataRef) -> MetadataRef ---
	DILocationGetInlinedAt :: proc(Location: MetadataRef) -> MetadataRef ---
	DIScopeGetFile :: proc(Scope: MetadataRef) -> MetadataRef ---
	DIFileGetDirectory :: proc(File: MetadataRef, Len: ^_c.uint) -> cstring ---
	DIFileGetFilename :: proc(File: MetadataRef, Len: ^_c.uint) -> cstring ---
	DIFileGetSource :: proc(File: MetadataRef, Len: ^_c.uint) -> cstring ---
	DIBuilderGetOrCreateTypeArray :: proc(Builder: DIBuilderRef, Data: ^MetadataRef, NumElements: _c.size_t) -> MetadataRef ---
	DIBuilderCreateSubroutineType :: proc(Builder: DIBuilderRef, File: MetadataRef, ParameterTypes: ^MetadataRef, NumParameterTypes: _c.uint, Flags: DIFlags) -> MetadataRef ---
	DIBuilderCreateMacro :: proc(Builder: DIBuilderRef, ParentMacroFile: MetadataRef, Line: _c.uint, RecordType: DWARFMacinfoRecordType, Name: cstring, NameLen: _c.size_t, Value: cstring, ValueLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateTempMacroFile :: proc(Builder: DIBuilderRef, ParentMacroFile: MetadataRef, Line: _c.uint, File: MetadataRef) -> MetadataRef ---
	DIBuilderCreateEnumerator :: proc(Builder: DIBuilderRef, Name: cstring, NameLen: _c.size_t, Value: i64, IsUnsigned: LLVMBool) -> MetadataRef ---
	DIBuilderCreateEnumerationType :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNumber: _c.uint, SizeInBits: u64, AlignInBits: u32, Elements: ^MetadataRef, NumElements: _c.uint, ClassTy: MetadataRef) -> MetadataRef ---
	DIBuilderCreateUnionType :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNumber: _c.uint, SizeInBits: u64, AlignInBits: u32, Flags: DIFlags, Elements: ^MetadataRef, NumElements: _c.uint, RunTimeLang: _c.uint, UniqueId: cstring, UniqueIdLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateArrayType :: proc(Builder: DIBuilderRef, Size: u64, AlignInBits: u32, Ty: MetadataRef, Subscripts: ^MetadataRef, NumSubscripts: _c.uint) -> MetadataRef ---
	DIBuilderCreateVectorType :: proc(Builder: DIBuilderRef, Size: u64, AlignInBits: u32, Ty: MetadataRef, Subscripts: ^MetadataRef, NumSubscripts: _c.uint) -> MetadataRef ---
	DIBuilderCreateUnspecifiedType :: proc(Builder: DIBuilderRef, Name: cstring, NameLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateBasicType :: proc(Builder: DIBuilderRef, Name: cstring, NameLen: _c.size_t, SizeInBits: u64, Encoding: _c.uint, Flags: DIFlags) -> MetadataRef ---
	DIBuilderCreatePointerType :: proc(Builder: DIBuilderRef, PointeeTy: MetadataRef, SizeInBits: u64, AlignInBits: u32, AddressSpace: _c.uint, Name: cstring, NameLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateStructType :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNumber: _c.uint, SizeInBits: u64, AlignInBits: u32, Flags: DIFlags, DerivedFrom: MetadataRef, Elements: ^MetadataRef, NumElements: _c.uint, RunTimeLang: _c.uint, VTableHolder: MetadataRef, UniqueId: cstring, UniqueIdLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateMemberType :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNo: _c.uint, SizeInBits: u64, AlignInBits: u32, OffsetInBits: u64, Flags: DIFlags, Ty: MetadataRef) -> MetadataRef ---
	DIBuilderCreateStaticMemberType :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNumber: _c.uint, Type: MetadataRef, Flags: DIFlags, ConstantVal: ValueRef, AlignInBits: u32) -> MetadataRef ---
	DIBuilderCreateMemberPointerType :: proc(Builder: DIBuilderRef, PointeeType: MetadataRef, ClassType: MetadataRef, SizeInBits: u64, AlignInBits: u32, Flags: DIFlags) -> MetadataRef ---
	DIBuilderCreateObjCIVar :: proc(Builder: DIBuilderRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNo: _c.uint, SizeInBits: u64, AlignInBits: u32, OffsetInBits: u64, Flags: DIFlags, Ty: MetadataRef, PropertyNode: MetadataRef) -> MetadataRef ---
	DIBuilderCreateObjCProperty :: proc(Builder: DIBuilderRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNo: _c.uint, GetterName: cstring, GetterNameLen: _c.size_t, SetterName: cstring, SetterNameLen: _c.size_t, PropertyAttributes: _c.uint, Ty: MetadataRef) -> MetadataRef ---
	DIBuilderCreateObjectPointerType :: proc(Builder: DIBuilderRef, Type: MetadataRef) -> MetadataRef ---
	DIBuilderCreateQualifiedType :: proc(Builder: DIBuilderRef, Tag: _c.uint, Type: MetadataRef) -> MetadataRef ---
	DIBuilderCreateReferenceType :: proc(Builder: DIBuilderRef, Tag: _c.uint, Type: MetadataRef) -> MetadataRef ---
	DIBuilderCreateNullPtrType :: proc(Builder: DIBuilderRef) -> MetadataRef ---
	DIBuilderCreateTypedef :: proc(Builder: DIBuilderRef, Type: MetadataRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNo: _c.uint, Scope: MetadataRef, AlignInBits: u32) -> MetadataRef ---
	DIBuilderCreateInheritance :: proc(Builder: DIBuilderRef, Ty: MetadataRef, BaseTy: MetadataRef, BaseOffset: u64, VBPtrOffset: u32, Flags: DIFlags) -> MetadataRef ---
	DIBuilderCreateForwardDecl :: proc(Builder: DIBuilderRef, Tag: _c.uint, Name: cstring, NameLen: _c.size_t, Scope: MetadataRef, File: MetadataRef, Line: _c.uint, RuntimeLang: _c.uint, SizeInBits: u64, AlignInBits: u32, UniqueIdentifier: cstring, UniqueIdentifierLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateReplaceableCompositeType :: proc(Builder: DIBuilderRef, Tag: _c.uint, Name: cstring, NameLen: _c.size_t, Scope: MetadataRef, File: MetadataRef, Line: _c.uint, RuntimeLang: _c.uint, SizeInBits: u64, AlignInBits: u32, Flags: DIFlags, UniqueIdentifier: cstring, UniqueIdentifierLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateBitFieldMemberType :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNumber: _c.uint, SizeInBits: u64, OffsetInBits: u64, StorageOffsetInBits: u64, Flags: DIFlags, Type: MetadataRef) -> MetadataRef ---
	DIBuilderCreateClassType :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNumber: _c.uint, SizeInBits: u64, AlignInBits: u32, OffsetInBits: u64, Flags: DIFlags, DerivedFrom: MetadataRef, Elements: ^MetadataRef, NumElements: _c.uint, VTableHolder: MetadataRef, TemplateParamsNode: MetadataRef, UniqueIdentifier: cstring, UniqueIdentifierLen: _c.size_t) -> MetadataRef ---
	DIBuilderCreateArtificialType :: proc(Builder: DIBuilderRef, Type: MetadataRef) -> MetadataRef ---
	DITypeGetName :: proc(DType: MetadataRef, Length: ^_c.size_t) -> cstring ---
	DITypeGetSizeInBits :: proc(DType: MetadataRef) -> u64 ---
	DITypeGetOffsetInBits :: proc(DType: MetadataRef) -> u64 ---
	DITypeGetAlignInBits :: proc(DType: MetadataRef) -> u32 ---
	DITypeGetLine :: proc(DType: MetadataRef) -> _c.uint ---
	DITypeGetFlags :: proc(DType: MetadataRef) -> DIFlags ---
	DIBuilderGetOrCreateSubrange :: proc(Builder: DIBuilderRef, LowerBound: i64, Count: i64) -> MetadataRef ---
	DIBuilderGetOrCreateArray :: proc(Builder: DIBuilderRef, Data: ^MetadataRef, NumElements: _c.size_t) -> MetadataRef ---
	DIBuilderCreateExpression :: proc(Builder: DIBuilderRef, Addr: ^u64, Length: _c.size_t) -> MetadataRef ---
	DIBuilderCreateConstantValueExpression :: proc(Builder: DIBuilderRef, Value: u64) -> MetadataRef ---
	DIBuilderCreateGlobalVariableExpression :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, Linkage: cstring, LinkLen: _c.size_t, File: MetadataRef, LineNo: _c.uint, Ty: MetadataRef, LocalToUnit: LLVMBool, Expr: MetadataRef, Decl: MetadataRef, AlignInBits: u32) -> MetadataRef ---
	GetDINodeTag :: proc(MD: MetadataRef) -> u16 ---
	DIGlobalVariableExpressionGetVariable :: proc(GVE: MetadataRef) -> MetadataRef ---
	DIGlobalVariableExpressionGetExpression :: proc(GVE: MetadataRef) -> MetadataRef ---
	DIVariableGetFile :: proc(Var: MetadataRef) -> MetadataRef ---
	DIVariableGetScope :: proc(Var: MetadataRef) -> MetadataRef ---
	DIVariableGetLine :: proc(Var: MetadataRef) -> _c.uint ---
	TemporaryMDNode :: proc(Ctx: ContextRef, Data: ^MetadataRef, NumElements: _c.size_t) -> MetadataRef ---
	DisposeTemporaryMDNode :: proc(TempNode: MetadataRef) ---
	MetadataReplaceAllUsesWith :: proc(TempTargetMetadata: MetadataRef, Replacement: MetadataRef) ---
	DIBuilderCreateTempGlobalVariableFwdDecl :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, Linkage: cstring, LnkLen: _c.size_t, File: MetadataRef, LineNo: _c.uint, Ty: MetadataRef, LocalToUnit: LLVMBool, Decl: MetadataRef, AlignInBits: u32) -> MetadataRef ---
	DIBuilderInsertDeclareBefore :: proc(Builder: DIBuilderRef, Storage: ValueRef, VarInfo: MetadataRef, Expr: MetadataRef, DebugLoc: MetadataRef, Instr: ValueRef) -> ValueRef ---
	DIBuilderInsertDeclareAtEnd :: proc(Builder: DIBuilderRef, Storage: ValueRef, VarInfo: MetadataRef, Expr: MetadataRef, DebugLoc: MetadataRef, Block: BasicBlockRef) -> ValueRef ---
	DIBuilderInsertDbgValueBefore :: proc(Builder: DIBuilderRef, Val: ValueRef, VarInfo: MetadataRef, Expr: MetadataRef, DebugLoc: MetadataRef, Instr: ValueRef) -> ValueRef ---
	DIBuilderInsertDbgValueAtEnd :: proc(Builder: DIBuilderRef, Val: ValueRef, VarInfo: MetadataRef, Expr: MetadataRef, DebugLoc: MetadataRef, Block: BasicBlockRef) -> ValueRef ---
	DIBuilderCreateAutoVariable :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, File: MetadataRef, LineNo: _c.uint, Ty: MetadataRef, AlwaysPreserve: LLVMBool, Flags: DIFlags, AlignInBits: u32) -> MetadataRef ---
	DIBuilderCreateParameterVariable :: proc(Builder: DIBuilderRef, Scope: MetadataRef, Name: cstring, NameLen: _c.size_t, ArgNo: _c.uint, File: MetadataRef, LineNo: _c.uint, Ty: MetadataRef, AlwaysPreserve: LLVMBool, Flags: DIFlags) -> MetadataRef ---
	GetSubprogram :: proc(Func: ValueRef) -> MetadataRef ---
	SetSubprogram :: proc(Func: ValueRef, SP: MetadataRef) ---
	DISubprogramGetLine :: proc(Subprogram: MetadataRef) -> _c.uint ---
	InstructionGetDebugLoc :: proc(Inst: ValueRef) -> MetadataRef ---
	InstructionSetDebugLoc :: proc(Inst: ValueRef, Loc: MetadataRef) ---
	GetMetadataKind :: proc(Metadata: MetadataRef) -> _c.uint ---
	CreateDisasm :: proc(TripleName: cstring, DisInfo: rawptr, TagType: _c.int, GetOpInfo: OpInfoCallback, SymbolLookUp: SymbolLookupCallback) -> DisasmContextRef ---
	CreateDisasmCPU :: proc(Triple: cstring, CPU: cstring, DisInfo: rawptr, TagType: _c.int, GetOpInfo: OpInfoCallback, SymbolLookUp: SymbolLookupCallback) -> DisasmContextRef ---
	CreateDisasmCPUFeatures :: proc(Triple: cstring, CPU: cstring, Features: cstring, DisInfo: rawptr, TagType: _c.int, GetOpInfo: OpInfoCallback, SymbolLookUp: SymbolLookupCallback) -> DisasmContextRef ---
	SetDisasmOptions :: proc(DC: DisasmContextRef, Options: u64) -> _c.int ---
	DisasmDispose :: proc(DC: DisasmContextRef) ---
	DisasmInstruction :: proc(DC: DisasmContextRef, Bytes: ^u8, BytesSize: u64, PC: u64, OutString: cstring, OutStringSize: _c.size_t) -> _c.size_t ---
	GetErrorTypeId :: proc(Err: ErrorRef) -> ErrorTypeId ---
	ConsumeError :: proc(Err: ErrorRef) ---
	GetErrorMessage :: proc(Err: ErrorRef) -> cstring ---
	DisposeErrorMessage :: proc(ErrMsg: cstring) ---
	GetStringErrorTypeId :: proc() -> ErrorTypeId ---
	CreateStringError :: proc(ErrMsg: cstring) -> ErrorRef ---
	InstallFatalErrorHandler :: proc(Handler: FatalErrorHandler) ---
	ResetFatalErrorHandler :: proc() ---
	EnablePrettyStackTrace :: proc() ---
	LinkInMCJIT :: proc() ---
	LinkInInterpreter :: proc() ---
	CreateGenericValueOfInt :: proc(Ty: TypeRef, N: _c.ulonglong, IsSigned: LLVMBool) -> GenericValueRef ---
	CreateGenericValueOfPointer :: proc(P: rawptr) -> GenericValueRef ---
	CreateGenericValueOfFloat :: proc(Ty: TypeRef, N: _c.double) -> GenericValueRef ---
	GenericValueIntWidth :: proc(GenValRef: GenericValueRef) -> _c.uint ---
	GenericValueToInt :: proc(GenVal: GenericValueRef, IsSigned: LLVMBool) -> _c.ulonglong ---
	GenericValueToPointer :: proc(GenVal: GenericValueRef) -> rawptr ---
	GenericValueToFloat :: proc(TyRef: TypeRef, GenVal: GenericValueRef) -> _c.double ---
	DisposeGenericValue :: proc(GenVal: GenericValueRef) ---
	CreateExecutionEngineForModule :: proc(OutEE: ^ExecutionEngineRef, M: ModuleRef, OutError: ^cstring) -> LLVMBool ---
	CreateInterpreterForModule :: proc(OutInterp: ^ExecutionEngineRef, M: ModuleRef, OutError: ^cstring) -> LLVMBool ---
	CreateJITCompilerForModule :: proc(OutJIT: ^ExecutionEngineRef, M: ModuleRef, OptLevel: _c.uint, OutError: ^cstring) -> LLVMBool ---
	InitializeMCJITCompilerOptions :: proc(Options: ^MCJITCompilerOptions, SizeOfOptions: _c.size_t) ---
	CreateMCJITCompilerForModule :: proc(OutJIT: ^ExecutionEngineRef, M: ModuleRef, Options: ^MCJITCompilerOptions, SizeOfOptions: _c.size_t, OutError: ^cstring) -> LLVMBool ---
	DisposeExecutionEngine :: proc(EE: ExecutionEngineRef) ---
	RunStaticConstructors :: proc(EE: ExecutionEngineRef) ---
	RunStaticDestructors :: proc(EE: ExecutionEngineRef) ---
	RunFunctionAsMain :: proc(EE: ExecutionEngineRef, F: ValueRef, ArgC: _c.uint, ArgV: ^cstring, EnvP: ^cstring) -> _c.int ---
	RunFunction :: proc(EE: ExecutionEngineRef, F: ValueRef, NumArgs: _c.uint, Args: ^GenericValueRef) -> GenericValueRef ---
	FreeMachineCodeForFunction :: proc(EE: ExecutionEngineRef, F: ValueRef) ---
	AddModule :: proc(EE: ExecutionEngineRef, M: ModuleRef) ---
	RemoveModule :: proc(EE: ExecutionEngineRef, M: ModuleRef, OutMod: ^ModuleRef, OutError: ^cstring) -> LLVMBool ---
	FindFunction :: proc(EE: ExecutionEngineRef, Name: cstring, OutFn: ^ValueRef) -> LLVMBool ---
	RecompileAndRelinkFunction :: proc(EE: ExecutionEngineRef, Fn: ValueRef) -> rawptr ---
	GetExecutionEngineTargetData :: proc(EE: ExecutionEngineRef) -> TargetDataRef ---
	GetExecutionEngineTargetMachine :: proc(EE: ExecutionEngineRef) -> TargetMachineRef ---
	AddGlobalMapping :: proc(EE: ExecutionEngineRef, Global: ValueRef, Addr: rawptr) ---
	GetPointerToGlobal :: proc(EE: ExecutionEngineRef, Global: ValueRef) -> rawptr ---
	GetGlobalValueAddress :: proc(EE: ExecutionEngineRef, Name: cstring) -> u64 ---
	GetFunctionAddress :: proc(EE: ExecutionEngineRef, Name: cstring) -> u64 ---
	ExecutionEngineGetErrMsg :: proc(EE: ExecutionEngineRef, OutError: ^cstring) -> LLVMBool ---
	CreateSimpleMCJITMemoryManager :: proc(Opaque: rawptr, AllocateCodeSection: MemoryManagerAllocateCodeSectionCallback, AllocateDataSection: MemoryManagerAllocateDataSectionCallback, FinalizeMemory: MemoryManagerFinalizeMemoryCallback, Destroy: MemoryManagerDestroyCallback) -> MCJITMemoryManagerRef ---
	DisposeMCJITMemoryManager :: proc(MM: MCJITMemoryManagerRef) ---
	CreateGDBRegistrationListener :: proc() -> JITEventListenerRef ---
	CreateIntelJITEventListener :: proc() -> JITEventListenerRef ---
	CreateOProfileJITEventListener :: proc() -> JITEventListenerRef ---
	CreatePerfJITEventListener :: proc() -> JITEventListenerRef ---
	ParseIRInContext :: proc(ContextRef: ContextRef, MemBuf: MemoryBufferRef, OutM: ^ModuleRef, OutMessage: ^cstring) -> LLVMBool ---
	LinkModules2 :: proc(Dest: ModuleRef, Src: ModuleRef) -> LLVMBool ---
	OrcCreateLLJITBuilder :: proc() -> OrcLLJITBuilderRef ---
	OrcDisposeLLJITBuilder :: proc(Builder: OrcLLJITBuilderRef) ---
	OrcLLJITBuilderSetJITTargetMachineBuilder :: proc(Builder: OrcLLJITBuilderRef, JTMB: OrcJITTargetMachineBuilderRef) ---
	OrcLLJITBuilderSetObjectLinkingLayerCreator :: proc(Builder: OrcLLJITBuilderRef, F: OrcLLJITBuilderObjectLinkingLayerCreatorFunction, Ctx: rawptr) ---
	OrcCreateLLJIT :: proc(Result: ^OrcLLJITRef, Builder: OrcLLJITBuilderRef) -> ErrorRef ---
	OrcDisposeLLJIT :: proc(J: OrcLLJITRef) -> ErrorRef ---
	OrcLLJITGetExecutionSession :: proc(J: OrcLLJITRef) -> OrcExecutionSessionRef ---
	OrcLLJITGetMainJITDylib :: proc(J: OrcLLJITRef) -> OrcJITDylibRef ---
	OrcLLJITGetTripleString :: proc(J: OrcLLJITRef) -> cstring ---
	OrcLLJITGetGlobalPrefix :: proc(J: OrcLLJITRef) -> _c.char ---
	OrcLLJITMangleAndIntern :: proc(J: OrcLLJITRef, UnmangledName: cstring) -> OrcSymbolStringPoolEntryRef ---
	OrcLLJITAddObjectFile :: proc(J: OrcLLJITRef, JD: OrcJITDylibRef, ObjBuffer: MemoryBufferRef) -> ErrorRef ---
	OrcLLJITAddObjectFileWithRT :: proc(J: OrcLLJITRef, RT: OrcResourceTrackerRef, ObjBuffer: MemoryBufferRef) -> ErrorRef ---
	OrcLLJITLookup :: proc(J: OrcLLJITRef, Result: ^OrcExecutorAddress, Name: cstring) -> ErrorRef ---
	OrcLLJITGetObjLinkingLayer :: proc(J: OrcLLJITRef) -> OrcObjectLayerRef ---
	OrcLLJITGetObjTransformLayer :: proc(J: OrcLLJITRef) -> OrcObjectTransformLayerRef ---
	OrcLLJITGetIRTransformLayer :: proc(J: OrcLLJITRef) -> OrcIRTransformLayerRef ---
	OrcLLJITGetDataLayoutStr :: proc(J: OrcLLJITRef) -> cstring ---

	@(link_name = "lto_get_version")
	lto_get_version :: proc() -> cstring ---

	@(link_name = "lto_get_error_message")
	lto_get_error_message :: proc() -> cstring ---

	@(link_name = "lto_module_is_object_file")
	lto_module_is_object_file :: proc(path: cstring) -> lto_bool_t ---

	@(link_name = "lto_module_is_object_file_for_target")
	lto_module_is_object_file_for_target :: proc(path: cstring, target_triple_prefix: cstring) -> lto_bool_t ---

	@(link_name = "lto_module_has_objc_category")
	lto_module_has_objc_category :: proc(mem: rawptr, length: _c.size_t) -> lto_bool_t ---

	@(link_name = "lto_module_is_object_file_in_memory")
	lto_module_is_object_file_in_memory :: proc(mem: rawptr, length: _c.size_t) -> lto_bool_t ---

	@(link_name = "lto_module_is_object_file_in_memory_for_target")
	lto_module_is_object_file_in_memory_for_target :: proc(mem: rawptr, length: _c.size_t, target_triple_prefix: cstring) -> lto_bool_t ---

	@(link_name = "lto_module_create")
	lto_module_create :: proc(path: cstring) -> lto_module_t ---

	@(link_name = "lto_module_create_from_memory")
	lto_module_create_from_memory :: proc(mem: rawptr, length: _c.size_t) -> lto_module_t ---

	@(link_name = "lto_module_create_from_memory_with_path")
	lto_module_create_from_memory_with_path :: proc(mem: rawptr, length: _c.size_t, path: cstring) -> lto_module_t ---

	@(link_name = "lto_module_create_in_local_context")
	lto_module_create_in_local_context :: proc(mem: rawptr, length: _c.size_t, path: cstring) -> lto_module_t ---

	@(link_name = "lto_module_create_in_codegen_context")
	lto_module_create_in_codegen_context :: proc(mem: rawptr, length: _c.size_t, path: cstring, cg: lto_code_gen_t) -> lto_module_t ---

	@(link_name = "lto_module_create_from_fd")
	lto_module_create_from_fd :: proc(fd: _c.int, path: cstring, file_size: _c.size_t) -> lto_module_t ---

	// @(link_name="lto_module_create_from_fd_at_offset")
	// lto_module_create_from_fd_at_offset :: proc(fd : _c.int, path : cstring, file_size : _c.size_t, map_size : _c.size_t, offset : off_t) -> lto_module_t ---;

	@(link_name = "lto_module_dispose")
	lto_module_dispose :: proc(mod: lto_module_t) ---

	@(link_name = "lto_module_get_target_triple")
	lto_module_get_target_triple :: proc(mod: lto_module_t) -> cstring ---

	@(link_name = "lto_module_set_target_triple")
	lto_module_set_target_triple :: proc(mod: lto_module_t, triple: cstring) ---

	@(link_name = "lto_module_get_num_symbols")
	lto_module_get_num_symbols :: proc(mod: lto_module_t) -> _c.uint ---

	@(link_name = "lto_module_get_symbol_name")
	lto_module_get_symbol_name :: proc(mod: lto_module_t, index: _c.uint) -> cstring ---

	@(link_name = "lto_module_get_symbol_attribute")
	lto_module_get_symbol_attribute :: proc(mod: lto_module_t, index: _c.uint) -> lto_symbol_attributes ---

	@(link_name = "lto_module_get_linkeropts")
	lto_module_get_linkeropts :: proc(mod: lto_module_t) -> cstring ---

	@(link_name = "lto_module_get_macho_cputype")
	lto_module_get_macho_cputype :: proc(mod: lto_module_t, out_cputype: ^_c.uint, out_cpusubtype: ^_c.uint) -> lto_bool_t ---

	@(link_name = "lto_module_has_ctor_dtor")
	lto_module_has_ctor_dtor :: proc(mod: lto_module_t) -> lto_bool_t ---

	@(link_name = "lto_codegen_set_diagnostic_handler")
	lto_codegen_set_diagnostic_handler :: proc(unamed0: lto_code_gen_t, unamed1: lto_diagnostic_handler_t, unamed2: rawptr) ---

	@(link_name = "lto_codegen_create")
	lto_codegen_create :: proc() -> lto_code_gen_t ---

	@(link_name = "lto_codegen_create_in_local_context")
	lto_codegen_create_in_local_context :: proc() -> lto_code_gen_t ---

	@(link_name = "lto_codegen_dispose")
	lto_codegen_dispose :: proc(unamed0: lto_code_gen_t) ---

	@(link_name = "lto_codegen_add_module")
	lto_codegen_add_module :: proc(cg: lto_code_gen_t, mod: lto_module_t) -> lto_bool_t ---

	@(link_name = "lto_codegen_set_module")
	lto_codegen_set_module :: proc(cg: lto_code_gen_t, mod: lto_module_t) ---

	@(link_name = "lto_codegen_set_debug_model")
	lto_codegen_set_debug_model :: proc(cg: lto_code_gen_t, unamed0: lto_debug_model) -> lto_bool_t ---

	@(link_name = "lto_codegen_set_pic_model")
	lto_codegen_set_pic_model :: proc(cg: lto_code_gen_t, unamed0: lto_codegen_model) -> lto_bool_t ---

	@(link_name = "lto_codegen_set_cpu")
	lto_codegen_set_cpu :: proc(cg: lto_code_gen_t, cpu: cstring) ---

	@(link_name = "lto_codegen_set_assembler_path")
	lto_codegen_set_assembler_path :: proc(cg: lto_code_gen_t, path: cstring) ---

	@(link_name = "lto_codegen_set_assembler_args")
	lto_codegen_set_assembler_args :: proc(cg: lto_code_gen_t, args: ^cstring, nargs: _c.int) ---

	@(link_name = "lto_codegen_add_must_preserve_symbol")
	lto_codegen_add_must_preserve_symbol :: proc(cg: lto_code_gen_t, symbol: cstring) ---

	@(link_name = "lto_codegen_write_merged_modules")
	lto_codegen_write_merged_modules :: proc(cg: lto_code_gen_t, path: cstring) -> lto_bool_t ---

	@(link_name = "lto_codegen_compile")
	lto_codegen_compile :: proc(cg: lto_code_gen_t, length: ^_c.size_t) -> rawptr ---

	@(link_name = "lto_codegen_compile_to_file")
	lto_codegen_compile_to_file :: proc(cg: lto_code_gen_t, name: ^cstring) -> lto_bool_t ---

	@(link_name = "lto_codegen_optimize")
	lto_codegen_optimize :: proc(cg: lto_code_gen_t) -> lto_bool_t ---

	@(link_name = "lto_codegen_compile_optimized")
	lto_codegen_compile_optimized :: proc(cg: lto_code_gen_t, length: ^_c.size_t) -> rawptr ---

	@(link_name = "lto_api_version")
	lto_api_version :: proc() -> _c.uint ---

	@(link_name = "lto_set_debug_options")
	lto_set_debug_options :: proc(options: ^cstring, number: _c.int) ---

	@(link_name = "lto_codegen_debug_options")
	lto_codegen_debug_options :: proc(cg: lto_code_gen_t, unamed0: cstring) ---

	@(link_name = "lto_codegen_debug_options_array")
	lto_codegen_debug_options_array :: proc(cg: lto_code_gen_t, unamed0: ^cstring, number: _c.int) ---

	@(link_name = "lto_initialize_disassembler")
	lto_initialize_disassembler :: proc() ---

	@(link_name = "lto_codegen_set_should_internalize")
	lto_codegen_set_should_internalize :: proc(cg: lto_code_gen_t, ShouldInternalize: lto_bool_t) ---

	@(link_name = "lto_codegen_set_should_embed_uselists")
	lto_codegen_set_should_embed_uselists :: proc(cg: lto_code_gen_t, ShouldEmbedUselists: lto_bool_t) ---

	@(link_name = "lto_input_create")
	lto_input_create :: proc(buffer: rawptr, buffer_size: _c.size_t, path: cstring) -> lto_input_t ---

	@(link_name = "lto_input_dispose")
	lto_input_dispose :: proc(input: lto_input_t) ---

	@(link_name = "lto_input_get_num_dependent_libraries")
	lto_input_get_num_dependent_libraries :: proc(input: lto_input_t) -> _c.uint ---

	@(link_name = "lto_input_get_dependent_library")
	lto_input_get_dependent_library :: proc(input: lto_input_t, index: _c.size_t, size: ^_c.size_t) -> cstring ---

	@(link_name = "lto_runtime_lib_symbols_list")
	lto_runtime_lib_symbols_list :: proc(size: ^_c.size_t) -> ^cstring ---

	@(link_name = "thinlto_create_codegen")
	thinlto_create_codegen :: proc() -> thinlto_code_gen_t ---

	@(link_name = "thinlto_codegen_dispose")
	thinlto_codegen_dispose :: proc(cg: thinlto_code_gen_t) ---

	@(link_name = "thinlto_codegen_add_module")
	thinlto_codegen_add_module :: proc(cg: thinlto_code_gen_t, identifier: cstring, data: cstring, length: _c.int) ---

	@(link_name = "thinlto_codegen_process")
	thinlto_codegen_process :: proc(cg: thinlto_code_gen_t) ---

	@(link_name = "thinlto_module_get_num_objects")
	thinlto_module_get_num_objects :: proc(cg: thinlto_code_gen_t) -> _c.uint ---

	@(link_name = "thinlto_module_get_object")
	thinlto_module_get_object :: proc(cg: thinlto_code_gen_t, index: _c.uint) -> LTOObjectBuffer ---

	@(link_name = "thinlto_module_get_num_object_files")
	thinlto_module_get_num_object_files :: proc(cg: thinlto_code_gen_t) -> _c.uint ---

	@(link_name = "thinlto_module_get_object_file")
	thinlto_module_get_object_file :: proc(cg: thinlto_code_gen_t, index: _c.uint) -> cstring ---

	@(link_name = "thinlto_codegen_set_pic_model")
	thinlto_codegen_set_pic_model :: proc(cg: thinlto_code_gen_t, unamed0: lto_codegen_model) -> lto_bool_t ---

	@(link_name = "thinlto_codegen_set_savetemps_dir")
	thinlto_codegen_set_savetemps_dir :: proc(cg: thinlto_code_gen_t, save_temps_dir: cstring) ---

	@(link_name = "thinlto_set_generated_objects_dir")
	thinlto_set_generated_objects_dir :: proc(cg: thinlto_code_gen_t, save_temps_dir: cstring) ---

	@(link_name = "thinlto_codegen_set_cpu")
	thinlto_codegen_set_cpu :: proc(cg: thinlto_code_gen_t, cpu: cstring) ---

	@(link_name = "thinlto_codegen_disable_codegen")
	thinlto_codegen_disable_codegen :: proc(cg: thinlto_code_gen_t, disable: lto_bool_t) ---

	@(link_name = "thinlto_codegen_set_codegen_only")
	thinlto_codegen_set_codegen_only :: proc(cg: thinlto_code_gen_t, codegen_only: lto_bool_t) ---

	@(link_name = "thinlto_debug_options")
	thinlto_debug_options :: proc(options: ^cstring, number: _c.int) ---

	@(link_name = "lto_module_is_thinlto")
	lto_module_is_thinlto :: proc(mod: lto_module_t) -> lto_bool_t ---

	@(link_name = "thinlto_codegen_add_must_preserve_symbol")
	thinlto_codegen_add_must_preserve_symbol :: proc(cg: thinlto_code_gen_t, name: cstring, length: _c.int) ---

	@(link_name = "thinlto_codegen_add_cross_referenced_symbol")
	thinlto_codegen_add_cross_referenced_symbol :: proc(cg: thinlto_code_gen_t, name: cstring, length: _c.int) ---

	@(link_name = "thinlto_codegen_set_cache_dir")
	thinlto_codegen_set_cache_dir :: proc(cg: thinlto_code_gen_t, cache_dir: cstring) ---

	@(link_name = "thinlto_codegen_set_cache_pruning_interval")
	thinlto_codegen_set_cache_pruning_interval :: proc(cg: thinlto_code_gen_t, interval: _c.int) ---

	@(link_name = "thinlto_codegen_set_final_cache_size_relative_to_available_space")
	thinlto_codegen_set_final_cache_size_relative_to_available_space :: proc(cg: thinlto_code_gen_t, percentage: _c.uint) ---

	@(link_name = "thinlto_codegen_set_cache_entry_expiration")
	thinlto_codegen_set_cache_entry_expiration :: proc(cg: thinlto_code_gen_t, expiration: _c.uint) ---

	@(link_name = "thinlto_codegen_set_cache_size_bytes")
	thinlto_codegen_set_cache_size_bytes :: proc(cg: thinlto_code_gen_t, max_size_bytes: _c.uint) ---

	@(link_name = "thinlto_codegen_set_cache_size_megabytes")
	thinlto_codegen_set_cache_size_megabytes :: proc(cg: thinlto_code_gen_t, max_size_megabytes: _c.uint) ---

	@(link_name = "thinlto_codegen_set_cache_size_files")
	thinlto_codegen_set_cache_size_files :: proc(cg: thinlto_code_gen_t, max_size_files: _c.uint) ---
	CreateBinary :: proc(MemBuf: MemoryBufferRef, Context: ContextRef, ErrorMessage: ^cstring) -> BinaryRef ---
	DisposeBinary :: proc(BR: BinaryRef) ---
	BinaryCopyMemoryBuffer :: proc(BR: BinaryRef) -> MemoryBufferRef ---
	BinaryGetType :: proc(BR: BinaryRef) -> BinaryType ---
	MachOUniversalBinaryCopyObjectForArch :: proc(BR: BinaryRef, Arch: cstring, ArchLen: _c.size_t, ErrorMessage: ^cstring) -> BinaryRef ---
	ObjectFileCopySectionIterator :: proc(BR: BinaryRef) -> SectionIteratorRef ---
	ObjectFileIsSectionIteratorAtEnd :: proc(BR: BinaryRef, SI: SectionIteratorRef) -> LLVMBool ---
	ObjectFileCopySymbolIterator :: proc(BR: BinaryRef) -> SymbolIteratorRef ---
	ObjectFileIsSymbolIteratorAtEnd :: proc(BR: BinaryRef, SI: SymbolIteratorRef) -> LLVMBool ---
	DisposeSectionIterator :: proc(SI: SectionIteratorRef) ---
	MoveToNextSection :: proc(SI: SectionIteratorRef) ---
	MoveToContainingSection :: proc(Sect: SectionIteratorRef, Sym: SymbolIteratorRef) ---
	DisposeSymbolIterator :: proc(SI: SymbolIteratorRef) ---
	MoveToNextSymbol :: proc(SI: SymbolIteratorRef) ---
	GetSectionName :: proc(SI: SectionIteratorRef) -> cstring ---
	GetSectionSize :: proc(SI: SectionIteratorRef) -> u64 ---
	GetSectionContents :: proc(SI: SectionIteratorRef) -> cstring ---
	GetSectionAddress :: proc(SI: SectionIteratorRef) -> u64 ---
	GetSectionContainsSymbol :: proc(SI: SectionIteratorRef, Sym: SymbolIteratorRef) -> LLVMBool ---
	GetRelocations :: proc(Section: SectionIteratorRef) -> RelocationIteratorRef ---
	DisposeRelocationIterator :: proc(RI: RelocationIteratorRef) ---
	IsRelocationIteratorAtEnd :: proc(Section: SectionIteratorRef, RI: RelocationIteratorRef) -> LLVMBool ---
	MoveToNextRelocation :: proc(RI: RelocationIteratorRef) ---
	GetSymbolName :: proc(SI: SymbolIteratorRef) -> cstring ---
	GetSymbolAddress :: proc(SI: SymbolIteratorRef) -> u64 ---
	GetSymbolSize :: proc(SI: SymbolIteratorRef) -> u64 ---
	GetRelocationOffset :: proc(RI: RelocationIteratorRef) -> u64 ---
	GetRelocationSymbol :: proc(RI: RelocationIteratorRef) -> SymbolIteratorRef ---
	GetRelocationType :: proc(RI: RelocationIteratorRef) -> u64 ---
	GetRelocationTypeName :: proc(RI: RelocationIteratorRef) -> cstring ---
	GetRelocationValueString :: proc(RI: RelocationIteratorRef) -> cstring ---
	CreateObjectFile :: proc(MemBuf: MemoryBufferRef) -> ObjectFileRef ---
	DisposeObjectFile :: proc(ObjectFile: ObjectFileRef) ---
	GetSections :: proc(ObjectFile: ObjectFileRef) -> SectionIteratorRef ---
	IsSectionIteratorAtEnd :: proc(ObjectFile: ObjectFileRef, SI: SectionIteratorRef) -> LLVMBool ---
	GetSymbols :: proc(ObjectFile: ObjectFileRef) -> SymbolIteratorRef ---
	IsSymbolIteratorAtEnd :: proc(ObjectFile: ObjectFileRef, SI: SymbolIteratorRef) -> LLVMBool ---
	OrcExecutionSessionSetErrorReporter :: proc(ES: OrcExecutionSessionRef, ReportError: OrcErrorReporterFunction, Ctx: rawptr) ---
	OrcExecutionSessionGetSymbolStringPool :: proc(ES: OrcExecutionSessionRef) -> OrcSymbolStringPoolRef ---
	OrcSymbolStringPoolClearDeadEntries :: proc(SSP: OrcSymbolStringPoolRef) ---
	OrcExecutionSessionIntern :: proc(ES: OrcExecutionSessionRef, Name: cstring) -> OrcSymbolStringPoolEntryRef ---
	OrcExecutionSessionLookup :: proc(ES: OrcExecutionSessionRef, K: OrcLookupKind, SearchOrder: OrcCJITDylibSearchOrder, SearchOrderSize: _c.size_t, Symbols: OrcCLookupSet, SymbolsSize: _c.size_t, HandleResult: OrcExecutionSessionLookupHandleResultFunction, Ctx: rawptr) ---
	OrcRetainSymbolStringPoolEntry :: proc(S: OrcSymbolStringPoolEntryRef) ---
	OrcReleaseSymbolStringPoolEntry :: proc(S: OrcSymbolStringPoolEntryRef) ---
	OrcSymbolStringPoolEntryStr :: proc(S: OrcSymbolStringPoolEntryRef) -> cstring ---
	OrcReleaseResourceTracker :: proc(RT: OrcResourceTrackerRef) ---
	OrcResourceTrackerTransferTo :: proc(SrcRT: OrcResourceTrackerRef, DstRT: OrcResourceTrackerRef) ---
	OrcResourceTrackerRemove :: proc(RT: OrcResourceTrackerRef) -> ErrorRef ---
	OrcDisposeDefinitionGenerator :: proc(DG: OrcDefinitionGeneratorRef) ---
	OrcDisposeMaterializationUnit :: proc(MU: OrcMaterializationUnitRef) ---
	OrcCreateCustomMaterializationUnit :: proc(Name: cstring, Ctx: rawptr, Syms: OrcCSymbolFlagsMapPairs, NumSyms: _c.size_t, InitSym: OrcSymbolStringPoolEntryRef, Materialize: OrcMaterializationUnitMaterializeFunction, Discard: OrcMaterializationUnitDiscardFunction, Destroy: OrcMaterializationUnitDestroyFunction) -> OrcMaterializationUnitRef ---
	OrcAbsoluteSymbols :: proc(Syms: OrcCSymbolMapPairs, NumPairs: _c.size_t) -> OrcMaterializationUnitRef ---
	OrcLazyReexports :: proc(LCTM: OrcLazyCallThroughManagerRef, ISM: OrcIndirectStubsManagerRef, SourceRef: OrcJITDylibRef, CallableAliases: OrcCSymbolAliasMapPairs, NumPairs: _c.size_t) -> OrcMaterializationUnitRef ---
	OrcDisposeMaterializationResponsibility :: proc(MR: OrcMaterializationResponsibilityRef) ---
	OrcMaterializationResponsibilityGetTargetDylib :: proc(MR: OrcMaterializationResponsibilityRef) -> OrcJITDylibRef ---
	OrcMaterializationResponsibilityGetExecutionSession :: proc(MR: OrcMaterializationResponsibilityRef) -> OrcExecutionSessionRef ---
	OrcMaterializationResponsibilityGetSymbols :: proc(MR: OrcMaterializationResponsibilityRef, NumPairs: ^_c.size_t) -> OrcCSymbolFlagsMapPairs ---
	OrcDisposeCSymbolFlagsMap :: proc(Pairs: OrcCSymbolFlagsMapPairs) ---
	OrcMaterializationResponsibilityGetInitializerSymbol :: proc(MR: OrcMaterializationResponsibilityRef) -> OrcSymbolStringPoolEntryRef ---
	OrcMaterializationResponsibilityGetRequestedSymbols :: proc(MR: OrcMaterializationResponsibilityRef, NumSymbols: ^_c.size_t) -> ^OrcSymbolStringPoolEntryRef ---
	OrcDisposeSymbols :: proc(Symbols: ^OrcSymbolStringPoolEntryRef) ---
	OrcMaterializationResponsibilityNotifyResolved :: proc(MR: OrcMaterializationResponsibilityRef, Symbols: OrcCSymbolMapPairs, NumPairs: _c.size_t) -> ErrorRef ---
	OrcMaterializationResponsibilityNotifyEmitted :: proc(MR: OrcMaterializationResponsibilityRef) -> ErrorRef ---
	OrcMaterializationResponsibilityDefineMaterializing :: proc(MR: OrcMaterializationResponsibilityRef, Pairs: OrcCSymbolFlagsMapPairs, NumPairs: _c.size_t) -> ErrorRef ---
	OrcMaterializationResponsibilityFailMaterialization :: proc(MR: OrcMaterializationResponsibilityRef) ---
	OrcMaterializationResponsibilityReplace :: proc(MR: OrcMaterializationResponsibilityRef, MU: OrcMaterializationUnitRef) -> ErrorRef ---
	OrcMaterializationResponsibilityDelegate :: proc(MR: OrcMaterializationResponsibilityRef, Symbols: ^OrcSymbolStringPoolEntryRef, NumSymbols: _c.size_t, Result: ^OrcMaterializationResponsibilityRef) -> ErrorRef ---
	OrcMaterializationResponsibilityAddDependencies :: proc(MR: OrcMaterializationResponsibilityRef, Name: OrcSymbolStringPoolEntryRef, Dependencies: OrcCDependenceMapPairs, NumPairs: _c.size_t) ---
	OrcMaterializationResponsibilityAddDependenciesForAll :: proc(MR: OrcMaterializationResponsibilityRef, Dependencies: OrcCDependenceMapPairs, NumPairs: _c.size_t) ---
	OrcExecutionSessionCreateBareJITDylib :: proc(ES: OrcExecutionSessionRef, Name: cstring) -> OrcJITDylibRef ---
	OrcExecutionSessionCreateJITDylib :: proc(ES: OrcExecutionSessionRef, Result: ^OrcJITDylibRef, Name: cstring) -> ErrorRef ---
	OrcExecutionSessionGetJITDylibByName :: proc(ES: OrcExecutionSessionRef, Name: cstring) -> OrcJITDylibRef ---
	OrcJITDylibCreateResourceTracker :: proc(JD: OrcJITDylibRef) -> OrcResourceTrackerRef ---
	OrcJITDylibGetDefaultResourceTracker :: proc(JD: OrcJITDylibRef) -> OrcResourceTrackerRef ---
	OrcJITDylibDefine :: proc(JD: OrcJITDylibRef, MU: OrcMaterializationUnitRef) -> ErrorRef ---
	OrcJITDylibClear :: proc(JD: OrcJITDylibRef) -> ErrorRef ---
	OrcJITDylibAddGenerator :: proc(JD: OrcJITDylibRef, DG: OrcDefinitionGeneratorRef) ---
	OrcCreateCustomCAPIDefinitionGenerator :: proc(F: OrcCAPIDefinitionGeneratorTryToGenerateFunction, Ctx: rawptr, Dispose: OrcDisposeCAPIDefinitionGeneratorFunction) -> OrcDefinitionGeneratorRef ---
	OrcLookupStateContinueLookup :: proc(S: OrcLookupStateRef, Err: ErrorRef) ---
	OrcCreateDynamicLibrarySearchGeneratorForProcess :: proc(Result: ^OrcDefinitionGeneratorRef, GlobalPrefx: _c.char, Filter: OrcSymbolPredicate, FilterCtx: rawptr) -> ErrorRef ---
	OrcCreateDynamicLibrarySearchGeneratorForPath :: proc(Result: ^OrcDefinitionGeneratorRef, FileName: cstring, GlobalPrefix: _c.char, Filter: OrcSymbolPredicate, FilterCtx: rawptr) -> ErrorRef ---
	OrcCreateStaticLibrarySearchGeneratorForPath :: proc(Result: ^OrcDefinitionGeneratorRef, ObjLayer: OrcObjectLayerRef, FileName: cstring, TargetTriple: cstring) -> ErrorRef ---
	OrcCreateNewThreadSafeContext :: proc() -> OrcThreadSafeContextRef ---
	OrcThreadSafeContextGetContext :: proc(TSCtx: OrcThreadSafeContextRef) -> ContextRef ---
	OrcDisposeThreadSafeContext :: proc(TSCtx: OrcThreadSafeContextRef) ---
	OrcCreateNewThreadSafeModule :: proc(M: ModuleRef, TSCtx: OrcThreadSafeContextRef) -> OrcThreadSafeModuleRef ---
	OrcDisposeThreadSafeModule :: proc(TSM: OrcThreadSafeModuleRef) ---
	OrcThreadSafeModuleWithModuleDo :: proc(TSM: OrcThreadSafeModuleRef, F: OrcGenericIRModuleOperationFunction, Ctx: rawptr) -> ErrorRef ---
	OrcJITTargetMachineBuilderDetectHost :: proc(Result: ^OrcJITTargetMachineBuilderRef) -> ErrorRef ---
	OrcJITTargetMachineBuilderCreateFromTargetMachine :: proc(TM: TargetMachineRef) -> OrcJITTargetMachineBuilderRef ---
	OrcDisposeJITTargetMachineBuilder :: proc(JTMB: OrcJITTargetMachineBuilderRef) ---
	OrcJITTargetMachineBuilderGetTargetTriple :: proc(JTMB: OrcJITTargetMachineBuilderRef) -> cstring ---
	OrcJITTargetMachineBuilderSetTargetTriple :: proc(JTMB: OrcJITTargetMachineBuilderRef, TargetTriple: cstring) ---
	OrcObjectLayerAddObjectFile :: proc(ObjLayer: OrcObjectLayerRef, JD: OrcJITDylibRef, ObjBuffer: MemoryBufferRef) -> ErrorRef ---
	OrcObjectLayerAddObjectFileWithRT :: proc(ObjLayer: OrcObjectLayerRef, RT: OrcResourceTrackerRef, ObjBuffer: MemoryBufferRef) -> ErrorRef ---
	OrcObjectLayerEmit :: proc(ObjLayer: OrcObjectLayerRef, R: OrcMaterializationResponsibilityRef, ObjBuffer: MemoryBufferRef) ---
	OrcDisposeObjectLayer :: proc(ObjLayer: OrcObjectLayerRef) ---
	OrcIRTransformLayerEmit :: proc(IRTransformLayer: OrcIRTransformLayerRef, MR: OrcMaterializationResponsibilityRef, TSM: OrcThreadSafeModuleRef) ---
	OrcIRTransformLayerSetTransform :: proc(IRTransformLayer: OrcIRTransformLayerRef, TransformFunction: OrcIRTransformLayerTransformFunction, Ctx: rawptr) ---
	OrcObjectTransformLayerSetTransform :: proc(ObjTransformLayer: OrcObjectTransformLayerRef, TransformFunction: OrcObjectTransformLayerTransformFunction, Ctx: rawptr) ---
	OrcCreateLocalIndirectStubsManager :: proc(TargetTriple: cstring) -> OrcIndirectStubsManagerRef ---
	OrcDisposeIndirectStubsManager :: proc(ISM: OrcIndirectStubsManagerRef) ---
	OrcCreateLocalLazyCallThroughManager :: proc(TargetTriple: cstring, ES: OrcExecutionSessionRef, ErrorHandlerAddr: u64, LCTM: ^OrcLazyCallThroughManagerRef) -> ErrorRef ---
	OrcDisposeLazyCallThroughManager :: proc(LCTM: OrcLazyCallThroughManagerRef) ---
	OrcCreateDumpObjects :: proc(DumpDir: cstring, IdentifierOverride: cstring) -> OrcDumpObjectsRef ---
	OrcDisposeDumpObjects :: proc(DumpObjects: OrcDumpObjectsRef) ---
	OrcDumpObjects_CallOperator :: proc(DumpObjects: OrcDumpObjectsRef, ObjBuffer: ^MemoryBufferRef) -> ErrorRef ---
	OrcCreateRTDyldObjectLinkingLayerWithSectionMemoryManager :: proc(ES: OrcExecutionSessionRef) -> OrcObjectLayerRef ---
	OrcCreateRTDyldObjectLinkingLayerWithMCJITMemoryManagerLikeCallbacks :: proc(ES: OrcExecutionSessionRef, CreateContextCtx: rawptr, CreateContext: MemoryManagerCreateContextCallback, NotifyTerminating: MemoryManagerNotifyTerminatingCallback, AllocateCodeSection: MemoryManagerAllocateCodeSectionCallback, AllocateDataSection: MemoryManagerAllocateDataSectionCallback, FinalizeMemory: MemoryManagerFinalizeMemoryCallback, Destroy: MemoryManagerDestroyCallback) -> OrcObjectLayerRef ---
	OrcRTDyldObjectLinkingLayerRegisterJITEventListener :: proc(RTDyldObjLinkingLayer: OrcObjectLayerRef, Listener: JITEventListenerRef) ---
	RemarkStringGetData :: proc(String: RemarkStringRef) -> cstring ---
	RemarkStringGetLen :: proc(String: RemarkStringRef) -> u32 ---
	RemarkDebugLocGetSourceFilePath :: proc(DL: RemarkDebugLocRef) -> RemarkStringRef ---
	RemarkDebugLocGetSourceLine :: proc(DL: RemarkDebugLocRef) -> u32 ---
	RemarkDebugLocGetSourceColumn :: proc(DL: RemarkDebugLocRef) -> u32 ---
	RemarkArgGetKey :: proc(Arg: RemarkArgRef) -> RemarkStringRef ---
	RemarkArgGetValue :: proc(Arg: RemarkArgRef) -> RemarkStringRef ---
	RemarkArgGetDebugLoc :: proc(Arg: RemarkArgRef) -> RemarkDebugLocRef ---
	RemarkEntryDispose :: proc(Remark: RemarkEntryRef) ---
	RemarkEntryGetType :: proc(Remark: RemarkEntryRef) -> RemarkType ---
	RemarkEntryGetPassName :: proc(Remark: RemarkEntryRef) -> RemarkStringRef ---
	RemarkEntryGetRemarkName :: proc(Remark: RemarkEntryRef) -> RemarkStringRef ---
	RemarkEntryGetFunctionName :: proc(Remark: RemarkEntryRef) -> RemarkStringRef ---
	RemarkEntryGetDebugLoc :: proc(Remark: RemarkEntryRef) -> RemarkDebugLocRef ---
	RemarkEntryGetHotness :: proc(Remark: RemarkEntryRef) -> u64 ---
	RemarkEntryGetNumArgs :: proc(Remark: RemarkEntryRef) -> u32 ---
	RemarkEntryGetFirstArg :: proc(Remark: RemarkEntryRef) -> RemarkArgRef ---
	RemarkEntryGetNextArg :: proc(It: RemarkArgRef, Remark: RemarkEntryRef) -> RemarkArgRef ---
	RemarkParserCreateYAML :: proc(Buf: rawptr, Size: u64) -> RemarkParserRef ---
	RemarkParserCreateBitstream :: proc(Buf: rawptr, Size: u64) -> RemarkParserRef ---
	RemarkParserGetNext :: proc(Parser: RemarkParserRef) -> RemarkEntryRef ---
	RemarkParserHasError :: proc(Parser: RemarkParserRef) -> LLVMBool ---
	RemarkParserGetErrorMessage :: proc(Parser: RemarkParserRef) -> cstring ---
	RemarkParserDispose :: proc(Parser: RemarkParserRef) ---
	RemarkVersion :: proc() -> u32 ---
	LoadLibraryPermanently :: proc(Filename: cstring) -> LLVMBool ---
	ParseCommandLineOptions :: proc(argc: _c.int, argv: ^cstring, Overview: cstring) ---
	SearchForAddressOfSymbol :: proc(symbolName: cstring) -> rawptr ---
	AddSymbol :: proc(symbolName: cstring, symbolValue: rawptr) ---
	InitializeAllDisassemblers :: proc() ---
	InitializeNativeTarget :: proc() -> LLVMBool ---
	InitializeNativeAsmParser :: proc() -> LLVMBool ---
	InitializeNativeAsmPrinter :: proc() -> LLVMBool ---
	InitializeNativeDisassembler :: proc() -> LLVMBool ---
	InitializeX86Target :: proc() -> LLVMBool ---
	InitializeX86AsmPrinter :: proc() -> LLVMBool ---
	InitializeX86TargetInfo :: proc() -> LLVMBool ---
	InitializeX86TargetMC :: proc() -> LLVMBool ---
	GetModuleDataLayout :: proc(M: ModuleRef) -> TargetDataRef ---
	SetModuleDataLayout :: proc(M: ModuleRef, DL: TargetDataRef) ---
	CreateTargetData :: proc(StringRep: cstring) -> TargetDataRef ---
	DisposeTargetData :: proc(TD: TargetDataRef) ---
	AddTargetLibraryInfo :: proc(TLI: TargetLibraryInfoRef, PM: PassManagerRef) ---
	CopyStringRepOfTargetData :: proc(TD: TargetDataRef) -> cstring ---
	ByteOrder :: proc(TD: TargetDataRef) -> ByteOrdering ---
	PointerSize :: proc(TD: TargetDataRef) -> _c.uint ---
	PointerSizeForAS :: proc(TD: TargetDataRef, AS: _c.uint) -> _c.uint ---
	IntPtrType :: proc(TD: TargetDataRef) -> TypeRef ---
	IntPtrTypeForAS :: proc(TD: TargetDataRef, AS: _c.uint) -> TypeRef ---
	IntPtrTypeInContext :: proc(C: ContextRef, TD: TargetDataRef) -> TypeRef ---
	IntPtrTypeForASInContext :: proc(C: ContextRef, TD: TargetDataRef, AS: _c.uint) -> TypeRef ---
	SizeOfTypeInBits :: proc(TD: TargetDataRef, Ty: TypeRef) -> _c.ulonglong ---
	StoreSizeOfType :: proc(TD: TargetDataRef, Ty: TypeRef) -> _c.ulonglong ---
	ABISizeOfType :: proc(TD: TargetDataRef, Ty: TypeRef) -> _c.ulonglong ---
	ABIAlignmentOfType :: proc(TD: TargetDataRef, Ty: TypeRef) -> _c.uint ---
	CallFrameAlignmentOfType :: proc(TD: TargetDataRef, Ty: TypeRef) -> _c.uint ---
	PreferredAlignmentOfType :: proc(TD: TargetDataRef, Ty: TypeRef) -> _c.uint ---
	PreferredAlignmentOfGlobal :: proc(TD: TargetDataRef, GlobalVar: ValueRef) -> _c.uint ---
	ElementAtOffset :: proc(TD: TargetDataRef, StructTy: TypeRef, Offset: _c.ulonglong) -> _c.uint ---
	OffsetOfElement :: proc(TD: TargetDataRef, StructTy: TypeRef, Element: _c.uint) -> _c.ulonglong ---
	GetFirstTarget :: proc() -> TargetRef ---
	GetNextTarget :: proc(T: TargetRef) -> TargetRef ---
	GetTargetFromName :: proc(Name: cstring) -> TargetRef ---
	GetTargetFromTriple :: proc(Triple: cstring, T: ^TargetRef, ErrorMessage: ^cstring) -> LLVMBool ---
	GetTargetName :: proc(T: TargetRef) -> cstring ---
	GetTargetDescription :: proc(T: TargetRef) -> cstring ---
	TargetHasJIT :: proc(T: TargetRef) -> LLVMBool ---
	TargetHasTargetMachine :: proc(T: TargetRef) -> LLVMBool ---
	TargetHasAsmBackend :: proc(T: TargetRef) -> LLVMBool ---
	CreateTargetMachine :: proc(T: TargetRef, Triple: cstring, CPU: cstring, Features: cstring, Level: CodeGenOptLevel, Reloc: RelocMode, CodeModel: CodeModel) -> TargetMachineRef ---
	DisposeTargetMachine :: proc(T: TargetMachineRef) ---
	GetTargetMachineTarget :: proc(T: TargetMachineRef) -> TargetRef ---
	GetTargetMachineTriple :: proc(T: TargetMachineRef) -> cstring ---
	GetTargetMachineCPU :: proc(T: TargetMachineRef) -> cstring ---
	GetTargetMachineFeatureString :: proc(T: TargetMachineRef) -> cstring ---
	CreateTargetDataLayout :: proc(T: TargetMachineRef) -> TargetDataRef ---
	SetTargetMachineAsmVerbosity :: proc(T: TargetMachineRef, VerboseAsm: LLVMBool) ---
	TargetMachineEmitToFile :: proc(T: TargetMachineRef, M: ModuleRef, Filename: cstring, codegen: CodeGenFileType, ErrorMessage: ^cstring) -> LLVMBool ---
	TargetMachineEmitToMemoryBuffer :: proc(T: TargetMachineRef, M: ModuleRef, codegen: CodeGenFileType, ErrorMessage: ^cstring, OutMemBuf: ^MemoryBufferRef) -> LLVMBool ---
	GetDefaultTargetTriple :: proc() -> cstring ---
	NormalizeTargetTriple :: proc(triple: cstring) -> cstring ---
	GetHostCPUName :: proc() -> cstring ---
	GetHostCPUFeatures :: proc() -> cstring ---
	AddAnalysisPasses :: proc(T: TargetMachineRef, PM: PassManagerRef) ---
}
