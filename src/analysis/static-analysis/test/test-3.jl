# Atomic Functions (B.12)

#
# Low-level intrinsics
#

for T in (Int32, Int64, UInt32, UInt64)
    ops = [:xchg, :add, :sub, :and, :or, :xor, :max, :min]

    ASs = Union{AS.Generic, AS.Global, AS.Shared}

    for op in ops
        # LLVM distinguishes signedness in the operation, not the integer type.
        rmw =  if T <: Unsigned && (op == :max || op == :min)
            Symbol("u$op")
        else
            Symbol("$op")
        end

        fn = Symbol("atomic_$(op)!")
        @eval @inline $fn(ptr::DevicePtr{$T,<:$ASs}, val::$T) =
            llvm_atomic_op($(Val(binops[rmw])), ptr, val)
    end
end

@generated function llvm_atomic_cas(ptr::DevicePtr{T,A}, cmp::T, val::T) where {T, A}
    T_val = convert(LLVMType, T)
    T_ptr = convert(LLVMType, DevicePtr{T,A})
    T_actual_ptr = LLVM.PointerType(T_val)

    llvm_f, _ = create_function(T_val, [T_ptr, T_val, T_val])

    Builder(JuliaContext()) do builder
        entry = BasicBlock(llvm_f, "entry", JuliaContext())
        position!(builder, entry)

        actual_ptr = inttoptr!(builder, parameters(llvm_f)[1], T_actual_ptr)

        res = atomic_cmpxchg!(builder, actual_ptr, parameters(llvm_f)[2],
                              parameters(llvm_f)[3], atomic_acquire_release, atomic_acquire,
                              #=single threaded=# false)

        rv = extract_value!(builder, res, 0)

        ret!(builder, rv)
    end

    call_function(llvm_f, T, Tuple{DevicePtr{T,A}, T, T}, :((ptr,cmp,val)))
end

for T in (Int32, Int64, UInt32, UInt64)
    @eval @inline atomic_cas!(ptr::DevicePtr{$T}, cmp::$T, val::$T) =
        llvm_atomic_cas(ptr, cmp, val)
end


## NVVM

for A in (AS.Generic, AS.Global, AS.Shared)
    for T in (Float32, Float64)
        nb = sizeof(T)*8

        if A == AS.Generic
            # FIXME: Ref doesn't encode the AS --> wrong mangling for nonzero address spaces
            intr = "llvm.nvvm.atomic.load.add.f$nb.p$(convert(Int, A))i8"
            @eval @inline atomic_add!(ptr::DevicePtr{$T,$A}, val::$T) =
                ccall($intr, llvmcall, $T, (Ref{$T}, $T), ptr, val)
        else
            import Base.Sys: WORD_SIZE
            if T == Float32
                T_val = "float"
            else
                T_val = "double"
            end
            if A == AS.Generic
                T_ptr = "$(T_val)*"
            else
                T_ptr = "$(T_val) addrspace($(convert(Int, A)))*"
            end
            intr = "llvm.nvvm.atomic.load.add.f$nb.p$(convert(Int, A))f$nb"
            @eval @inline atomic_add!(ptr::DevicePtr{$T,$A}, val::$T) = Base.llvmcall(
                $("declare $T_val @$intr($T_ptr, $T_val)",
                  "%ptr = inttoptr i$WORD_SIZE %0 to $T_ptr
                   %rv = call $T_val @$intr($T_ptr %ptr, $T_val %1)
                   ret $T_val %rv"), $T,
                Tuple{DevicePtr{$T,$A}, $T}, ptr, val)
        end
    end

    for T in (Int32,), op in (:inc, :dec)
        nb = sizeof(T)*8
        fn = Symbol("atomic_$(op)!")

        if A == AS.Generic
            # FIXME: Ref doesn't encode the AS --> wrong mangling for nonzero address spaces
            intr = "llvm.nvvm.atomic.load.$op.$nb.p$(convert(Int, A))i8"
            @eval @inline $fn(ptr::DevicePtr{$T,$A}, val::$T) =
                ccall($intr, llvmcall, $T, (Ref{$T}, $T), ptr, val)
        else
            import Base.Sys: WORD_SIZE
            T_val = "i32"
            if A == AS.Generic
                T_ptr = "$(T_val)*"
            else
                T_ptr = "$(T_val) addrspace($(convert(Int, A)))*"
            end
            intr = "llvm.nvvm.atomic.load.$op.$nb.p$(convert(Int, A))i$nb"
            @eval @inline $fn(ptr::DevicePtr{$T,$A}, val::$T) = Base.llvmcall(
                $("declare $T_val @$intr($T_ptr, $T_val)",
                  "%ptr = inttoptr i$WORD_SIZE %0 to $T_ptr
                   %rv = call $T_val @$intr($T_ptr %ptr, $T_val %1)
                   ret $T_val %rv"), $T,
                Tuple{DevicePtr{$T,$A}, $T}, ptr, val)
        end
    end
end


## Julia

# floating-point CAS via bitcasting

inttype(::Type{T}) where {T<:Integer} = T
inttype(::Type{Float16}) = Int16
inttype(::Type{Float32}) = Int32
inttype(::Type{Float64}) = Int64

for T in [Float32, Float64]
    @eval @inline function atomic_cas!(ptr::DevicePtr{$T}, cmp::$T, new::$T)
        IT = inttype($T)
        cmp_i = reinterpret(IT, cmp)
        new_i = reinterpret(IT, new)
        old_i = atomic_cas!(convert(DevicePtr{IT}, ptr), cmp_i, new_i)
        return reinterpret($T, old_i)
    end
end

# floating-point operations via atomic_cas!

const opnames = Dict{Symbol, Symbol}(:- => :sub, :* => :mul, :/ => :div)

for T in [Float32, Float64]
    for op in [:-, :*, :/, :max, :min]
        opname = get(opnames, op, op)
        fn = Symbol("atomic_$(opname)!")
        @eval @inline function $fn(ptr::DevicePtr{$T}, val::$T)
            old = Base.unsafe_load(ptr, 1)
            while true
                cmp = old
                new = $op(old, val)
                old = atomic_cas!(ptr, cmp, new)
                (old == cmp) && return new
            end
        end
    end
end

# CUDA.jl atomics
for (op,impl) in [(+)      => atomic_add!,
                  (-)      => atomic_sub!,
                  (&)      => atomic_and!,
                  (|)      => atomic_or!,
                  (⊻)      => atomic_xor!,
                  Base.max => atomic_max!,
                  Base.min => atomic_min!]
    @eval @inline atomic_arrayset(A::CuDeviceArray, I::Integer, ::typeof($op), val) =
        $impl(pointer(A, I), val)
end
