/* DCRTE-ET Milestone 3 parallel-transport frame field. */

class TransportFrame {
  float tx,ty,tz,nx,ny,nz,bx,by,bz;
  float twistFromPrevious;
  float confidence=1;
}

class TransportFrameField {
  TransportFrame[] frames;
  float meanRotation;
  float maxRotation;
  float cumulativeRotation;
  int elevatedRotationCount;
  int signFlipCount;
  int discontinuityCount;
  float continuityScore;
  String initialNormalPolicy="unresolved";
  boolean valid;

  JSONObject toJSON(){JSONObject json=new JSONObject();json.setString("method","parallel_transport");json.setString("initial_normal_policy",initialNormalPolicy);json.setInt("sample_count",frames==null?0:frames.length);json.setFloat("mean_rotation",meanRotation);json.setFloat("max_rotation",maxRotation);json.setFloat("cumulative_rotation",cumulativeRotation);json.setInt("elevated_rotation_count",elevatedRotationCount);json.setInt("sign_flips",signFlipCount);json.setInt("discontinuities",discontinuityCount);json.setFloat("continuity_score",continuityScore);json.setBoolean("valid",valid);return json;}
}

class DCRTEParallelTransportBuilder {
  TransportFrameField build(CenterlineModel centerline,PCAFrame pca){
    TransportFrameField field=new TransportFrameField();if(centerline==null||!centerline.valid||centerline.points==null||centerline.points.length<2)return field;
    int n=centerline.points.length;field.frames=new TransportFrame[n];
    CenterlinePoint first=centerline.points[0];float[] t={first.tangentX,first.tangentY,first.tangentZ};dcrteNormalizeInPlace(t);
    float[] normal={pca.axis2X,pca.axis2Y,pca.axis2Z};float alignment=abs(dcrteDot(t[0],t[1],t[2],normal[0],normal[1],normal[2]));
    if(alignment>0.92f){normal=dcrteLeastAlignedAxis(t);field.initialNormalPolicy="least_aligned_world_axis";}else field.initialNormalPolicy="pca_second_axis";
    dcrteOrthogonalize(normal,t);float[] binormal=new float[3];dcrteCross(t,normal,binormal);dcrteNormalizeInPlace(binormal);dcrteCross(binormal,t,normal);dcrteNormalizeInPlace(normal);
    field.frames[0]=dcrteFrame(t,normal,binormal,0,1);
    for(int i=1;i<n;i++){
      float[] t1={centerline.points[i].tangentX,centerline.points[i].tangentY,centerline.points[i].tangentZ};dcrteNormalizeInPlace(t1);
      TransportFrame previous=field.frames[i-1];float[] t0={previous.tx,previous.ty,previous.tz};float[] n0={previous.nx,previous.ny,previous.nz};float[] b0={previous.bx,previous.by,previous.bz};
      float dot=constrain(dcrteDot(t0[0],t0[1],t0[2],t1[0],t1[1],t1[2]),-1,1);float[] axis=new float[3];dcrteCross(t0,t1,axis);float axisLength=dcrteMagnitude(axis[0],axis[1],axis[2]);float angle=atan2(axisLength,dot);
      float[] nextN=new float[3],nextB=new float[3];float confidence=1;
      if(dot<-0.995f){field.discontinuityCount++;confidence=0;System.arraycopy(n0,0,nextN,0,3);System.arraycopy(b0,0,nextB,0,3);}else if(axisLength<0.000001f){System.arraycopy(n0,0,nextN,0,3);System.arraycopy(b0,0,nextB,0,3);}else{axis[0]/=axisLength;axis[1]/=axisLength;axis[2]/=axisLength;dcrteRotateRodrigues(n0,axis,angle,nextN);dcrteRotateRodrigues(b0,axis,angle,nextB);}
      dcrteOrthogonalize(nextN,t1);dcrteCross(t1,nextN,nextB);dcrteNormalizeInPlace(nextB);dcrteCross(nextB,t1,nextN);dcrteNormalizeInPlace(nextN);
      if(dcrteDot(nextN[0],nextN[1],nextN[2],n0[0],n0[1],n0[2])<-0.2f&&angle<HALF_PI){field.signFlipCount++;confidence*=0.3f;}
      if(angle>0.35f)field.elevatedRotationCount++;field.cumulativeRotation+=angle;field.maxRotation=max(field.maxRotation,angle);field.frames[i]=dcrteFrame(t1,nextN,nextB,angle,confidence);
    }
    field.meanRotation=n<=1?0:field.cumulativeRotation/(n-1);field.continuityScore=constrain(1.0f-(field.maxRotation/PI)*0.5f-field.discontinuityCount*0.25f-field.signFlipCount*0.1f,0,1);field.valid=field.discontinuityCount==0&&field.signFlipCount==0&&field.continuityScore>=0.70f;return field;
  }
}

TransportFrame dcrteFrame(float[] t,float[] n,float[] b,float twist,float confidence){TransportFrame f=new TransportFrame();f.tx=t[0];f.ty=t[1];f.tz=t[2];f.nx=n[0];f.ny=n[1];f.nz=n[2];f.bx=b[0];f.by=b[1];f.bz=b[2];f.twistFromPrevious=twist;f.confidence=confidence;return f;}
float[] dcrteLeastAlignedAxis(float[] tangent){float ax=abs(tangent[0]),ay=abs(tangent[1]),az=abs(tangent[2]);if(ax<=ay&&ax<=az)return new float[]{1,0,0};if(ay<=az)return new float[]{0,1,0};return new float[]{0,0,1};}
void dcrteOrthogonalize(float[] vector,float[] tangent){float projection=dcrteDot(vector[0],vector[1],vector[2],tangent[0],tangent[1],tangent[2]);vector[0]-=projection*tangent[0];vector[1]-=projection*tangent[1];vector[2]-=projection*tangent[2];dcrteNormalizeInPlace(vector);}
void dcrteRotateRodrigues(float[] vector,float[] axis,float angle,float[] out){float c=cos(angle),s=sin(angle),dot=dcrteDot(axis[0],axis[1],axis[2],vector[0],vector[1],vector[2]);out[0]=vector[0]*c+(axis[1]*vector[2]-axis[2]*vector[1])*s+axis[0]*dot*(1-c);out[1]=vector[1]*c+(axis[2]*vector[0]-axis[0]*vector[2])*s+axis[1]*dot*(1-c);out[2]=vector[2]*c+(axis[0]*vector[1]-axis[1]*vector[0])*s+axis[2]*dot*(1-c);}
