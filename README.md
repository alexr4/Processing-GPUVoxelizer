# Processing-GPUVoxelizer
Using GPU instance and Compute Shader to create a real-time voxelizer in processing.org

This sketch is a try to implement a voxelizer using compute shader for real-time computation and GPU instance for voxel display. The shape is filled.

This implement may not be the more optimized version. The basic idea behind this is, for each voxel, find the nearest vertex from the mesh. If the distance is less than the voxel size, it's an edge. If not we check the dot product between the ray from the neighbor vertex to the voxel and the normal of the neighbor. If the two rays are near to be opposed (dot <= -.9) then the voxel is inside the shape.

Any contribution are welcome if you want to make a better solution.
Everything has been tested on Windows with an NVidia gtx 1070 & 1060 GPU

![Voxel](voxelizer-thumb.gif)

If you found this usefull please consider telling us with a simple 'thank you mail' at contact@bonjour-lab.com
You can find more about our work here www.bonjour-lab.com | [@bonjourLab](https://www.instagram.com/bonjourlab/) | [@arivaux](https://www.instagram.com/arivaux/)