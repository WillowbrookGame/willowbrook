import {furnitureCatalog,furnitureBounds,furnitureOverlaps,furnitureSurfaces} from './furniture-catalog.js';
import {roomsForHome} from './housing.js';
export const furnitureGrid=.25;
export function furniturePlacement(home,candidate,{ignoreId=null}={}){
 const kind=candidate.kind,room=candidate.room??0,rotation=candidate.rotation??0,supportId=candidate.supportId??null,surfaceId=candidate.surfaceId??null;
 const item={kind,room,x:candidate.x,z:candidate.z,rotation,supportId,surfaceId,y:0};
 if(!Object.hasOwn(furnitureCatalog,kind)||!Number.isInteger(room)||!roomsForHome(home.variant)[room]||!Number.isInteger(rotation)||rotation<0||rotation>3||![item.x,item.z].every(n=>Number.isFinite(n)&&Math.abs(n*4-Math.round(n*4))<1e-7))return {error:'Choose a valid quarter-step position and rotation'};
 if(Math.abs(item.x)>4||Math.abs(item.z)>3)return {error:'Choose a spot inside this room'};
 const bounds=furnitureBounds(kind,item.x,item.z,rotation);
 if(bounds.left< -5.5||bounds.right>5.5||bounds.back< -4.5||bounds.front>4.5)return {error:'This item needs more space away from the wall'};
 if(room===0&&bounds.left<1.5&&bounds.right> -1.5&&bounds.front>1.5)return {error:'Keep the doorway clear'};
 if(supportId!==null){
  if(typeof supportId!=='string'||supportId===ignoreId||!furnitureCatalog[kind].surfacePlaceable)return {error:'This item must stay on the floor'};
  const support=home.furniture.find(f=>f.id===supportId);
  if(!support||support.supportId!=null||(support.room??0)!==room)return {error:'Choose a table or shelf in this room'};
  const surface=furnitureSurfaces[support.kind]?.find(s=>s.id===surfaceId);
  if(!surface)return {error:'Choose an available furniture surface'};
  const turn=(support.rotation??0)*Math.PI/2,dx=item.x-support.x,dz=item.z-support.z;
  const localX=dx*Math.cos(turn)-dz*Math.sin(turn),localZ=dx*Math.sin(turn)+dz*Math.cos(turn),relativeRotation=(rotation-(support.rotation??0)+4)%4;
  const decor=furnitureCatalog[kind],w=relativeRotation%2?decor.surfaceDepth:decor.surfaceWidth,d=relativeRotation%2?decor.surfaceWidth:decor.surfaceDepth;
  const localBounds={left:localX-w/2,right:localX+w/2,back:localZ-d/2,front:localZ+d/2};
  if(localBounds.left<surface.x-surface.width/2-.001||localBounds.right>surface.x+surface.width/2+.001||localBounds.back<surface.z-surface.depth/2-.001||localBounds.front>surface.z+surface.depth/2+.001||furnitureCatalog[kind].height>surface.clearance)return {error:'This item does not fit on that surface'};
  item.y=surface.y;
 }else if(surfaceId!==null)return {error:'Choose the furniture supporting this surface'};
 for(const other of home.furniture){
  if(other.id===ignoreId||(other.room??0)!==room||other.id===supportId)continue;
  if(supportId!==null){if(other.supportId!==supportId||other.surfaceId!==surfaceId)continue;}
  else if(other.supportId!=null)continue;
  if(furnitureOverlaps(other,item))return {error:'This spot already has furniture'};
 }
 return {error:null,item};
}
export const furnitureHasChildren=(home,id)=>home.furniture.some(f=>f.supportId===id);
