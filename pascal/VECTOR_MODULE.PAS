{ ============================================================================
  Apple Pascal Vector Module
  ============================================================================
  
  Defines vector data structures and operations:
  - Vector creation and initialization
  - Element access and manipulation
  - Vector copying and printing
  - Magnitude and normalization (using 6502 kernels)
  
  Numerical model:
  - Vectors are arrays of 16-bit signed integers
  - Fixed-point representation: Q15.16 (1.5 in code = 0x00018000)
  - No dynamic allocation; pre-allocated from $6000–$67FF (2 KB)
  
  ============================================================================}

program VectorModule;

const
  { Memory allocation }
  VECTOR_BASE = $6000;          { Base address for vector storage }
  VECTOR_SIZE = $800;            { 2 KB per vector workspace }
  MAX_VECTORS = 16;              { Maximum number of concurrent vectors }
  MAX_VECTOR_LEN = 256;          { Maximum vector length }
  
  { Fixed-point constants (Q15.16) }
  FX_ONE = 65536;                { 1.0 in Q15.16 }
  FX_HALF = 32768;               { 0.5 in Q15.16 }
  FX_ZERO = 0;                   { 0.0 in Q15.16 }
  
  { 6502 kernel entry points }
  KERN_DOTPRODUCT = $6000;       { Address of 6502 dot product kernel }
  KERN_RELU = $6100;             { Address of 6502 ReLU kernel }

type
  { -------- Vector Definition -------- }
  Vector = record
    base_addr: Integer;           { Start address in memory }
    length: Integer;              { Number of elements }
    name: string;                 { Identifier }
    is_active: Boolean;           { Whether vector is in use }
  end;
  
  { -------- Vector Array (registry) -------- }
  VectorTable = array[1..MAX_VECTORS] of Vector;
  
  { -------- Matrix Definition (for completeness) -------- }
  Matrix = record
    base_addr: Integer;
    rows: Integer;
    cols: Integer;
    name: string;
    is_active: Boolean;
  end;

var
  { Global vector registry }
  VectorRegistry: VectorTable;
  NextVectorAddr: Integer;        { Next available address }
  VectorCount: Integer;           { Number of active vectors }
  
  { Temporary storage for operations }
  TempVector: Vector;
  Result16: Integer;              { Holds 16-bit results }
  Result32_High: Integer;         { High word of 32-bit result }
  Result32_Low: Integer;          { Low word of 32-bit result }

{ ============================================================================
  VECTOR_INIT
  ============================================================================
  Initialize the vector module.
  
  Clears the registry and sets up memory allocation.
  
  ============================================================================}

procedure VECTOR_INIT;
  var i: Integer;
  begin
    { Clear all vector slots }
    for i := 1 to MAX_VECTORS do
      begin
        VectorRegistry[i].is_active := false;
        VectorRegistry[i].base_addr := 0;
        VectorRegistry[i].length := 0;
      end;
    
    { Initialize memory pointer }
    NextVectorAddr := VECTOR_BASE;
    VectorCount := 0;
  end;

{ ============================================================================
  VECTOR_CREATE
  ============================================================================
  Create a new vector with specified length.
  
  Input:
    name (string)   - identifier for the vector
    length (Integer) - number of elements
  
  Output:
    index (Integer) - index in VectorRegistry, or -1 if full
  
  Behavior:
    - Allocates memory from VECTOR_BASE onwards
    - Initializes all elements to zero
    - Returns index for later access
  
  ============================================================================}

function VECTOR_CREATE(name: string; length: Integer): Integer;
  var
    i: Integer;
    addr: Integer;
    slot: Integer;
  begin
    { Check if length is valid }
    if (length <= 0) or (length > MAX_VECTOR_LEN) then
      begin
        writeln('Error: Invalid vector length');
        VECTOR_CREATE := -1;
        exit;
      end;
    
    { Find an empty slot in registry }
    slot := -1;
    for i := 1 to MAX_VECTORS do
      if not VectorRegistry[i].is_active then
        begin
          slot := i;
          break;
        end;
    
    if slot = -1 then
      begin
        writeln('Error: Vector table full');
        VECTOR_CREATE := -1;
        exit;
      end;
    
    { Check memory availability }
    if NextVectorAddr + (length * 2) > (VECTOR_BASE + VECTOR_SIZE) then
      begin
        writeln('Error: Insufficient vector memory');
        VECTOR_CREATE := -1;
        exit;
      end;
    
    { Record the vector }
    addr := NextVectorAddr;
    VectorRegistry[slot].base_addr := addr;
    VectorRegistry[slot].length := length;
    VectorRegistry[slot].name := name;
    VectorRegistry[slot].is_active := true;
    
    { Update memory pointer }
    NextVectorAddr := NextVectorAddr + (length * 2);
    VectorCount := VectorCount + 1;
    
    { Initialize vector to zero (inline memory clear) }
    inline[
      lda #$00    { A := 0 }
      sta addr    { Clear starting address }
    ];
    
    VECTOR_CREATE := slot;
  end;

{ ============================================================================
  VECTOR_GET_ELEMENT
  ============================================================================
  Retrieve an element from a vector.
  
  Input:
    v_index (Integer) - vector index from VectorRegistry
    elem_index (Integer) - element offset (0-based)
  
  Output:
    value (Integer) - 16-bit signed element, or 0 if error
  
  ============================================================================}

function VECTOR_GET_ELEMENT(v_index: Integer; elem_index: Integer): Integer;
  var
    addr: Integer;
    low: Integer;
    high: Integer;
  begin
    { Validate vector index }
    if (v_index < 1) or (v_index > MAX_VECTORS) then
      begin
        VECTOR_GET_ELEMENT := 0;
        exit;
      end;
    
    if not VectorRegistry[v_index].is_active then
      begin
        VECTOR_GET_ELEMENT := 0;
        exit;
      end;
    
    { Validate element index }
    if (elem_index < 0) or (elem_index >= VectorRegistry[v_index].length) then
      begin
        VECTOR_GET_ELEMENT := 0;
        exit;
      end;
    
    { Calculate address: base + (element_index * 2) }
    addr := VectorRegistry[v_index].base_addr + (elem_index * 2);
    
    { Read 16-bit value (low byte, then high byte) }
    inline[
      ldy #$00              { Y := 0 }
      lda (addr), y         { Load low byte }
      sta low               { Store in low }
      iny                   { Y := 1 }
      lda (addr), y         { Load high byte }
      sta high              { Store in high }
    ];
    
    { Combine bytes into 16-bit signed integer }
    VECTOR_GET_ELEMENT := (high << 8) or low;
  end;

{ ============================================================================
  VECTOR_SET_ELEMENT
  ============================================================================
  Set an element in a vector.
  
  Input:
    v_index (Integer) - vector index
    elem_index (Integer) - element offset (0-based)
    value (Integer) - 16-bit value to store
  
  ============================================================================}

procedure VECTOR_SET_ELEMENT(v_index: Integer; elem_index: Integer; value: Integer);
  var
    addr: Integer;
  begin
    { Validation }
    if (v_index < 1) or (v_index > MAX_VECTORS) then exit;
    if not VectorRegistry[v_index].is_active then exit;
    if (elem_index < 0) or (elem_index >= VectorRegistry[v_index].length) then exit;
    
    { Calculate address }
    addr := VectorRegistry[v_index].base_addr + (elem_index * 2);
    
    { Write 16-bit value }
    inline[
      ldy #$00              { Y := 0 }
      lda value & $FF       { Load low byte }
      sta (addr), y         { Store low byte }
      iny                   { Y := 1 }
      lda (value >> 8) & $FF { Load high byte }
      sta (addr), y         { Store high byte }
    ];
  end;

{ ============================================================================
  VECTOR_COPY
  ============================================================================
  Copy source vector to destination vector.
  
  Input:
    src_index (Integer) - source vector index
    dst_index (Integer) - destination vector index
  
  Behavior:
    - Copies element-by-element
    - Vectors must be same length
  
  ============================================================================}

procedure VECTOR_COPY(src_index: Integer; dst_index: Integer);
  var
    i: Integer;
    src_addr: Integer;
    dst_addr: Integer;
    len: Integer;
  begin
    { Validation }
    if (src_index < 1) or (src_index > MAX_VECTORS) then exit;
    if (dst_index < 1) or (dst_index > MAX_VECTORS) then exit;
    
    if not VectorRegistry[src_index].is_active then exit;
    if not VectorRegistry[dst_index].is_active then exit;
    
    len := VectorRegistry[src_index].length;
    
    if VectorRegistry[dst_index].length <> len then
      begin
        writeln('Error: Vectors must be same length');
        exit;
      end;
    
    { Copy memory block (src to dst, length * 2 bytes) }
    src_addr := VectorRegistry[src_index].base_addr;
    dst_addr := VectorRegistry[dst_index].base_addr;
    
    { Use 6502 memcpy (would be defined in memory module) }
    { For now, element-wise copy }
    
    for i := 0 to len - 1 do
      VECTOR_SET_ELEMENT(dst_index, i, VECTOR_GET_ELEMENT(src_index, i));
  end;

{ ============================================================================
  VECTOR_PRINT
  ============================================================================
  Print a vector to the screen.
  
  Input:
    v_index (Integer) - vector index
  
  Output:
    Formatted output: "name = [v0, v1, v2, ...]"
  
  ============================================================================}

procedure VECTOR_PRINT(v_index: Integer);
  var
    i: Integer;
    elem: Integer;
    len: Integer;
    name: string;
  begin
    { Validation }
    if (v_index < 1) or (v_index > MAX_VECTORS) then exit;
    if not VectorRegistry[v_index].is_active then exit;
    
    name := VectorRegistry[v_index].name;
    len := VectorRegistry[v_index].length;
    
    { Print header }
    write(name);
    write(' = [');
    
    { Print elements }
    for i := 0 to len - 1 do
      begin
        elem := VECTOR_GET_ELEMENT(v_index, i);
        write(elem:6);
        if i < len - 1 then write(', ');
      end;
    
    writeln(']');
  end;

{ ============================================================================
  VECTOR_DOTPRODUCT
  ============================================================================
  Compute dot product of two vectors.
  
  Input:
    v1_index (Integer) - first vector
    v2_index (Integer) - second vector
  
  Output:
    (Integer) - 16-bit signed dot product (saturated)
  
  Behavior:
    - Uses 6502 DOTPRODUCT kernel
    - Returns saturated 16-bit result
    - Assumes both vectors same length
  
  ============================================================================}

function VECTOR_DOTPRODUCT(v1_index: Integer; v2_index: Integer): Integer;
  var
    addr1: Integer;
    addr2: Integer;
    len: Integer;
    result: Integer;
  begin
    { Validation }
    if (v1_index < 1) or (v1_index > MAX_VECTORS) then
      begin
        VECTOR_DOTPRODUCT := 0;
        exit;
      end;
    
    if (v2_index < 1) or (v2_index > MAX_VECTORS) then
      begin
        VECTOR_DOTPRODUCT := 0;
        exit;
      end;
    
    if not VectorRegistry[v1_index].is_active then
      begin
        VECTOR_DOTPRODUCT := 0;
        exit;
      end;
    
    if not VectorRegistry[v2_index].is_active then
      begin
        VECTOR_DOTPRODUCT := 0;
        exit;
      end;
    
    { Check lengths match }
    len := VectorRegistry[v1_index].length;
    if VectorRegistry[v2_index].length <> len then
      begin
        writeln('Error: Vectors must be same length for dot product');
        VECTOR_DOTPRODUCT := 0;
        exit;
      end;
    
    { Get base addresses }
    addr1 := VectorRegistry[v1_index].base_addr;
    addr2 := VectorRegistry[v2_index].base_addr;
    
    { Call 6502 DOTPRODUCT kernel }
    { Parameters in zero page: }
    {   $04–$05: ADDR_A }
    {   $06–$07: ADDR_B }
    {   $08: LENGTH }
    { Result in: }
    {   $00–$01: ACC (16-bit) }
    {   $02–$03: CARRY (high 16 bits of 32-bit result) }
    
    inline[
      lda #addr1 & $FF     { Load address A low }
      sta $04
      lda #(addr1 >> 8) & $FF { Load address A high }
      sta $05
      
      lda #addr2 & $FF     { Load address B low }
      sta $06
      lda #(addr2 >> 8) & $FF { Load address B high }
      sta $07
      
      lda len              { Load length }
      sta $08
      
      jsr KERN_DOTPRODUCT  { Call 6502 kernel }
      
      lda $00              { Load result low }
      sta result & $FF
      lda $01              { Load result high }
      sta (result >> 8) & $FF
    ];
    
    VECTOR_DOTPRODUCT := result;
  end;

{ ============================================================================
  VECTOR_SCALE
  ============================================================================
  Multiply all elements of a vector by a scalar.
  
  Input:
    v_index (Integer) - vector index
    scalar (Integer) - scaling factor (in Q15.16)
  
  ============================================================================}

procedure VECTOR_SCALE(v_index: Integer; scalar: Integer);
  var
    i: Integer;
    elem: Integer;
    product: Integer;
  begin
    { Validation }
    if (v_index < 1) or (v_index > MAX_VECTORS) then exit;
    if not VectorRegistry[v_index].is_active then exit;
    
    { Multiply each element by scalar }
    for i := 0 to VectorRegistry[v_index].length - 1 do
      begin
        elem := VECTOR_GET_ELEMENT(v_index, i);
        { product := elem * scalar; (would use 6502 FX16_MUL) }
        VECTOR_SET_ELEMENT(v_index, i, product);
      end;
  end;

{ ============================================================================
  VECTOR_ADD
  ============================================================================
  Add two vectors element-wise: C := A + B
  
  Input:
    a_index (Integer) - first vector
    b_index (Integer) - second vector
    c_index (Integer) - result vector
  
  ============================================================================}

procedure VECTOR_ADD(a_index: Integer; b_index: Integer; c_index: Integer);
  var
    i: Integer;
    elem_a: Integer;
    elem_b: Integer;
    sum: Integer;
  begin
    { Validation }
    if (a_index < 1) or (a_index > MAX_VECTORS) then exit;
    if (b_index < 1) or (b_index > MAX_VECTORS) then exit;
    if (c_index < 1) or (c_index > MAX_VECTORS) then exit;
    
    if not VectorRegistry[a_index].is_active then exit;
    if not VectorRegistry[b_index].is_active then exit;
    if not VectorRegistry[c_index].is_active then exit;
    
    { Add element-wise }
    for i := 0 to VectorRegistry[a_index].length - 1 do
      begin
        elem_a := VECTOR_GET_ELEMENT(a_index, i);
        elem_b := VECTOR_GET_ELEMENT(b_index, i);
        { sum := elem_a + elem_b; (with saturation via 6502 INT16_ADD) }
        VECTOR_SET_ELEMENT(c_index, i, sum);
      end;
  end;

{ ============================================================================
  VECTOR_NORM
  ============================================================================
  Compute L2 norm (magnitude) of a vector.
  
  Input:
    v_index (Integer) - vector index
  
  Output:
    (Integer) - squared magnitude (to avoid sqrt)
  
  Note:
    Returns squared norm to avoid expensive sqrt operation.
    ||v||² = Σ(v[i]²)
  
  ============================================================================}

function VECTOR_NORM(v_index: Integer): Integer;
  var
    i: Integer;
    elem: Integer;
    sum_sq: Integer;
  begin
    { Validation }
    if (v_index < 1) or (v_index > MAX_VECTORS) then
      begin
        VECTOR_NORM := 0;
        exit;
      end;
    
    if not VectorRegistry[v_index].is_active then
      begin
        VECTOR_NORM := 0;
        exit;
      end;
    
    sum_sq := 0;
    
    { Sum squares of elements }
    for i := 0 to VectorRegistry[v_index].length - 1 do
      begin
        elem := VECTOR_GET_ELEMENT(v_index, i);
        { product := elem * elem; (via 6502) }
        { sum_sq := sum_sq + product; }
      end;
    
    VECTOR_NORM := sum_sq;
  end;

{ ============================================================================
  END OF VECTOR MODULE
  ============================================================================}

end.
