

public class ComputeShader {
  public final static int MAX_PARTICLES = 1000000;
  private PGL pgl;
  private GL4 gl;
  private PApplet app;
  private PGraphics ctx;

  //particles component
  private int pclCount;
  private final static int VEC4_CMP = 4; //Number of component per vertex
  private final static int NBR_COMP = 4 * 2; //Number of component per vertex

  //compute shader + FloatBuffer to handle the datas
  private ComputeProgram computeprogram;
  private float[] datas;
  private FloatBuffer pclbuffer;
  private int pclHandle;

  //mesh data
  private int meshdataCount;
  private float[] meshdatas;
  private FloatBuffer meshbuffer;
  private int meshHandle;

  private VBOInterleaved vbo;

  public ComputeShader(PApplet app, PGL pgl, GL4 gl, PGraphics ctx) {
    this.app = app;
    this.pgl = pgl;
    this.gl = gl;
    this.ctx = ctx;
  }

  public void init(String path, int count, int meshdataCount) {
    pclCount = count;
    this.meshdataCount = meshdataCount;

    //init Float Buffer
    pclbuffer = Buffers.newDirectFloatBuffer(pclCount * NBR_COMP); 
    meshbuffer = Buffers.newDirectFloatBuffer(meshdataCount * NBR_COMP); 

    computeprogram = new ComputeProgram(gl, loadAsText(path+"/pcl.comp"));
    IntBuffer intBuffer = IntBuffer.allocate(2);
    gl.glGenBuffers(2, intBuffer);
    pclHandle = intBuffer.get(0);
    meshHandle = intBuffer.get(1);

    println("init");
  }

  public void bindVBO(VBOInterleaved vbo) {

    // Select the VBO, GPU memory data, to use for vertices -> update the VBO Object
    // transfer data to VBO, this perform the copy of data from CPU -> GPU memory
    this.vbo = vbo;
    this.vbo.initInstanceVBO(this.pgl, this.pclHandle, this.pclbuffer);
    println("bind");
  }

  public void setPoints(float[] ivertList) {
    this.datas = ivertList;
    //for (int i=0; i<this.datas[i]; i++) {
    //  this.pclbuffer.put(i, this.datas[i]);
    //}
    pclbuffer.rewind();
    pclbuffer.put(ivertList);
    pclbuffer.rewind();
    //println("set instance position");
  }

  public void setMeshdata(float[] ivertList) {
    this.meshdatas = ivertList;
    //for (int i=0; i<this.datas[i]; i++) {
    //  this.pclbuffer.put(i, this.datas[i]);
    //}
    meshbuffer.rewind();
    meshbuffer.put(meshdatas);
    meshbuffer.rewind();
    //println("set mesh data");
  }

  public void execute(float voxelScale) {
    computeprogram.begin();

    int meshdataCountLoc = computeprogram.getUniformLocation("meshdataCount");
    gl.glUniform1i(meshdataCountLoc, meshdataCount);
    
    int voxelSizeLoc = computeprogram.getUniformLocation("voxelSize");
    gl.glUniform1f(voxelSizeLoc, voxelScale);
    
    int mouseLoc = computeprogram.getUniformLocation("mouse");
    gl.glUniform2f(mouseLoc, (float)mouseX / (float)width, (float)mouseY / (float)height);
    
    //bind  mesh data to buffer
    gl.glBindBuffer(GL4.GL_SHADER_STORAGE_BUFFER, meshHandle);
    gl.glBufferData(GL4.GL_SHADER_STORAGE_BUFFER, this.meshbuffer.limit() * Float.BYTES, this.meshbuffer, GL.GL_STATIC_DRAW);

    //bind buffer for storage
    gl.glBindBufferBase(GL4.GL_SHADER_STORAGE_BUFFER, 0, pclHandle);
    gl.glBindBufferBase(GL4.GL_SHADER_STORAGE_BUFFER, 1, meshHandle);


    //execute compute shader
    computeprogram.compute(ceil(pclCount/1024.0), 1, 1); //check if the Working group is correct

    //unbind buffer
    gl.glBindBufferBase(GL4.GL_SHADER_STORAGE_BUFFER, 0, 0);
    gl.glBindBuffer(GL4.GL_SHADER_STORAGE_BUFFER, 0);
    computeprogram.end();
  }

  public void getGPUData() {
    //None. For now we only send data to VBO and not retreiving data into a CPU Buffer
    //see https://github.com/alexr4/jogl-compute-shaders-fireworks for implementation example
  }

  public void dispose() {
    computeprogram.dispose();
  }
}
