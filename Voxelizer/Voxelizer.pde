/*
early prototype
 Key : 
 'd' : display debug
 's' display based shape
 
 TABS:
 ComputeShader: Compute shader controller (load shader, bind buffer, execute...)
 ComputeShaderUtils: Compute Shader parser
 MeshDescription: describes all the voxels parameters
 VBO: custom interleaved buffer object supporting GPU instance. Does not support Stroke Shader (need to create custom one) or material params (ambiant, specualr, shininess...) but can be easily extended.
 
 */

import peasy.*;
import com.jogamp.common.nio.Buffers;
import com.jogamp.opengl.GL;
import com.jogamp.opengl.GL2;
import com.jogamp.opengl.GL2ES2;
import com.jogamp.opengl.GL4;
import java.util.*;
import java.nio.*;

//Sketch parameters
int fwidth = 1000;
int fheight = 1000;
float skecthScale = 0.75;

PeasyCam cam;

//assets & global params
String path;
PShape basedShape;
float scale3d = 100.0; //define the scale of the shape as loaded obj are small
PVector world = new PVector(4000, 4000, 4000);

//VBO: custom vertex buffer object for gpu mesh instancing
VBOInterleaved vbo;
//compute shader for mesh collision
ComputeShader pcl;

int numberOfInstance;
int nbrOfCompPerDataInInstance = 4 * 2; //offset position and scale are Vec4 so we have 4 component * 2 vectors
float[] perInstanceData; //voxel interleaved buffer (position + scale)

int nbrOfCompPerMeshData = 4 * 2; //vertex position and normal are Vec4 so we have 4 component * 2 vectors
float[] perMeshData; //mesh data interleaved buffer (position + normal)

//debug
boolean init;
boolean debug;
boolean displayBased = false;
PShape normalShape; //debug shape for normal orientation

void settings() {
  int swidth = round(fwidth * skecthScale);
  int sheight = round(fheight * skecthScale); 
  size(swidth, sheight, P3D);
}

void setup() {
  cam = new PeasyCam(this, 4000);
  path = sketchPath("../data/");
}

void draw() {
  if (!init) {
    println("load OBJ");
    basedShape = loadShape(path+"StanfordBunnySimple.obj");
    normalShape = createShape(GROUP);

    println("obj Loaded\nParse OBJ data");
    int cols   = floor(world.x / (scale.x * 2));
    int rows   = floor(world.y / (scale.y * 2));
    int depth  = floor(world.z / (scale.z * 2));
    numberOfInstance = cols * rows * depth;
    println("Number of voxels", numberOfInstance);

    //our array of data per instance will contains the position of the mesh (vec4) and the normal/direction of the instance (vec4).
    nbrOfCompPerDataInInstance = 4 * 2; //offset position and scale are Vec4 so we have 4 component * 2 vectors
    perInstanceData = new float[numberOfInstance * nbrOfCompPerDataInInstance]; 

    //feed perInstanceData buffer with position and scale for each voxel
    int index = 0;
    for (int c=0; c<cols; c++) {
      for (int r=0; r<rows; r++) {
        for (int d=0; d<depth; d++) {
          float x = c * scale.x * 2 - world.x * 0.5 + scale.x;
          float y = r * scale.y * 2 - world.y * 0.5 + scale.y;
          float z = d * scale.z * 2 - world.z * 0.5 + scale.z;

          perInstanceData[index * nbrOfCompPerDataInInstance + 0] = x;
          perInstanceData[index * nbrOfCompPerDataInInstance + 1] = y;
          perInstanceData[index * nbrOfCompPerDataInInstance + 2] = z;
          perInstanceData[index * nbrOfCompPerDataInInstance + 3] = 0.0;

          perInstanceData[index * nbrOfCompPerDataInInstance + 4] = 1;
          perInstanceData[index * nbrOfCompPerDataInInstance + 5] = 1;
          perInstanceData[index * nbrOfCompPerDataInInstance + 6] = 1;
          perInstanceData[index * nbrOfCompPerDataInInstance + 7] = 0.0;

          index ++;
        }
      }
    }

    //rescale bunny + define mesh data buffer for Compute Shader
    nbrOfCompPerMeshData = 4 * 2; //vertex position and normal are Vec4 so we have 4 component * 2 vectors
    perMeshData = new float[basedShape.getChildCount() * nbrOfCompPerMeshData];  //we will take only gravity center
    //in order to avoid too much data I decided to use the gravity center of each triangle as position and compute the face normal. By this we avoid using the same vertex multiple time or having too much data
    for (int ci=0; ci<basedShape.getChildCount(); ci++) {
      PShape triangle = basedShape.getChild(ci);

      PVector v0 = triangle.getVertex(0);
      PVector v1 = triangle.getVertex(1);
      PVector v2 = triangle.getVertex(2);

      PVector n0 = triangle.getNormal(0);
      PVector n1 = triangle.getNormal(1);
      PVector n2 = triangle.getNormal(2);

      v0.mult(scale3d);
      v1.mult(scale3d);
      v2.mult(scale3d);

      PVector gravity = v0.copy().add(v1).add(v2);
      gravity.div(3.0);

      PVector normal = n0.copy().add(n1).add(n2);
      normal.div(3.0);
      normal.normalize();


      perMeshData[ci * nbrOfCompPerMeshData + 0] = gravity.x;
      perMeshData[ci * nbrOfCompPerMeshData + 1] = gravity.y;
      perMeshData[ci * nbrOfCompPerMeshData + 2] = gravity.z;
      perMeshData[ci * nbrOfCompPerMeshData + 3] = 0.0;

      perMeshData[ci * nbrOfCompPerMeshData + 4] = normal.x;
      perMeshData[ci * nbrOfCompPerMeshData + 5] = normal.y;
      perMeshData[ci * nbrOfCompPerMeshData + 6] = normal.z;
      perMeshData[ci * nbrOfCompPerMeshData + 7] = 0.0;

      PShape line = createShape();
      line.beginShape(LINES);
      line.stroke(255);
      line.vertex(gravity.x, gravity.y, gravity.z);
      line.vertex(gravity.x + normal.x * 25.0, gravity.y + normal.y * 25.0, gravity.z + normal.z * 25.0);
      line.endShape();

      normalShape.addChild(line);
    }

    println("OBJ data parsed\nCreate VBO");
    //Init GL4 context for compute shader init
    PJOGL pgl = (PJOGL) beginPGL();  
    GL4 gl = pgl.gl.getGL4();

    //create and init custom VBO
    vbo = new VBOInterleaved(this, path+"voxel/");
    vbo.initVBO(g, indices.length, numberOfInstance); //create a VBO with a mesh of 'indices.length' vertices and 'numberOfInstance' of instances
    updateGeometry(vbo); //update the geometry of the shape (position)
    updateColor(vbo); //update the colors of the shape
    vbo.updateMeshVBO(); //update the interleaved VBO for shared mesh data
    println("VBO Created\nStart Draw");

    //create and init compute shader
    pcl = new ComputeShader(this, pgl, gl, g);
    pcl.init(path+"voxel/", numberOfInstance, basedShape.getChildCount()); //init CS with the folder of the shader, the number of instance and the number of vertex to test (which will be bound to the CS)
    pcl.setPoints(perInstanceData); //feed the CS with the voxels data
    pcl.setMeshdata(perMeshData);//feed the CS with the mesh data
    pcl.bindVBO(vbo);//bind the CS directly to the VBO
    println("point cloud ready with "+pcl.pclCount);

    init = true;
  } else {
    background(0);

    // lights();
    ambientLight(10, 10, 10);
    directionalLight(255, 255, 255, -1, 0.75, -0.75);
    directionalLight(128, 128, 128, 1, -0.75, -0.75);

    //reset axis from c4d to processing
    rotateX(PI);
    rotateY(PI*0.5);
    
    float angle = millis() * 0.001;

    if (displayBased) {
      //display 3D based shape
      pushMatrix();
      scale(scale3d);
      rotateY(angle);
      shape(basedShape);
      popMatrix();
    } else {
      for (int ci=0; ci<basedShape.getChildCount(); ci++) {
        PShape triangle = basedShape.getChild(ci);

        PVector v0 = triangle.getVertex(0);
        PVector v1 = triangle.getVertex(1);
        PVector v2 = triangle.getVertex(2);

        PVector n0 = triangle.getNormal(0);
        PVector n1 = triangle.getNormal(1);
        PVector n2 = triangle.getNormal(2);

        v0.mult(scale3d);
        v1.mult(scale3d);
        v2.mult(scale3d);

        PVector gravity = v0.copy().add(v1).add(v2);
        gravity.div(3.0);
        

        PVector normal = n0.copy().add(n1).add(n2);
        normal.div(3.0);
        normal.normalize();
        
        normal = computeRodrigueRotation(new PVector(0, 1, 0), normal, angle);
        gravity = computeRodrigueRotation(new PVector(0, 1, 0), gravity, angle);


        perMeshData[ci * nbrOfCompPerMeshData + 0] = gravity.x;
        perMeshData[ci * nbrOfCompPerMeshData + 1] = gravity.y;
        perMeshData[ci * nbrOfCompPerMeshData + 2] = gravity.z;
        perMeshData[ci * nbrOfCompPerMeshData + 3] = 0.0;

        perMeshData[ci * nbrOfCompPerMeshData + 4] = normal.x;
        perMeshData[ci * nbrOfCompPerMeshData + 5] = normal.y;
        perMeshData[ci * nbrOfCompPerMeshData + 6] = normal.z;
        perMeshData[ci * nbrOfCompPerMeshData + 7] = 0.0;
      }
      
      //update mesh data for next iteration
      pcl.setMeshdata(perMeshData);//feed the CS with the mesh data
      pcl.execute(voxelScale * 4.0);//execute compute shader, I bound a min dist value of voxelSize * 4 to the shader to avoid hole inside the shape. Try with differents values
      vbo.draw(g); //draw gpu instance voxels
    }

    if (debug) {
      stroke(255);
      noFill();
      box(4000);
      gizmo(500);
      pushMatrix();
      rotateY(angle);
      shape(normalShape); //display debug shape
      popMatrix();
    }

    cam.beginHUD();
    noLights();
    fill(255);
    text("GPUInstance + Compute Shader — fps : "+round(frameRate)+"\nNumber of instance: "+vbo.maxInstance+"\nNumber of vertex to test: "+basedShape.getChildCount(), 20, 20);
    cam.endHUD();
    surface.setTitle("GPUInstance — fps : "+round(frameRate));
  }
}


void gizmo(float len) {
  stroke(255, 0, 0);
  line(0, 0, 0, len, 0, 0);
  stroke(0, 255, 0);
  line(0, 0, 0, 0, len, 0);
  stroke(0, 0, 255);
  line(0, 0, 0, 0, 0, len);
}

void keyPressed() {
  switch(key) {
  case 'd':
  case 'D' :
    debug = !debug;
    break;
  case 's':
  case 'S' :
    displayBased = !displayBased;
    break;
  }
}

// K = axe
// V = vecteur to rotate
PVector computeRodrigueRotation(PVector _k, PVector _v, float theta)
{
 PVector k = _k.copy().normalize();
 PVector v = _v.copy().normalize();
  // Olinde Rodrigues formula : Vrot = v* cos(theta) + (k x v) * sin(theta) + k * (k . v) * (1 - cos(theta));
  PVector kcrossv = k.cross(v);
  float kdotv = k.dot(v);

  float x = v.x * cos(theta) + kcrossv.x * sin(theta) + k.x * kdotv * (1 - cos(theta));
  float y = v.y * cos(theta) + kcrossv.y * sin(theta) + k.y * kdotv * (1 - cos(theta));
  float z = v.z * cos(theta) + kcrossv.z * sin(theta) + k.z * kdotv * (1 - cos(theta));
  
  PVector rot = new PVector(x, y, z);
  return rot.mult(_v.mag());
}
