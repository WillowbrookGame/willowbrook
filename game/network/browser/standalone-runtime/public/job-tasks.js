import {expandedJobs} from './expanded-jobs.js';
import {plots} from './town-layout.js';
import {businessDefinitions} from './business-interiors.js';
export const parcelStation=Object.freeze({id:'parcel',label:'Collect a parcel',x:-19,z:26,radius:2,interiorBusiness:'store'});
export const deliveryDestinations=Object.freeze([...['library','vet','salon','bank','cafe'].map(id=>{const b=businessDefinitions[id];return Object.freeze({id,label:b.name+' front door',x:b.doorX,z:b.doorZ+(b.doorZ>b.z?2:-2),radius:2.3,interiorBusiness:null});}),...plots.map(([x,z],i)=>Object.freeze({id:'home-'+i,label:'Home '+(i+1)+' front path',x,z:z+7,radius:1.7,interiorBusiness:null})),Object.freeze({id:'nursery',label:'Little Nursery entrance',x:-23,z:44,radius:1.7,interiorBusiness:null})]);
export const nurseryStation=Object.freeze({id:'nursery-start',label:'Pick up the watering can',x:-23,z:50,radius:1.7,interiorBusiness:null});
export const nurseryTasks=Object.freeze([
 {id:'water-0',label:'Water the red flowers',x:-25.5,z:47},
 {id:'water-1',label:'Water the purple flowers',x:-20.5,z:50},
 {id:'water-2',label:'Water the green seedling',x:-25.5,z:53},
 {id:'pot',label:'Pot a new seedling',x:-23,z:52.2}
].map(t=>Object.freeze({...t,radius:1.7,interiorBusiness:null,durationMs:2000})));
export const workTaskDefinitions=Object.freeze({...expandedJobs,nursery:Object.freeze({title:'Nursery helper',station:nurseryStation,tasks:nurseryTasks})});
export const deliveryStop=id=>deliveryDestinations.find(t=>t.id===id)||deliveryDestinations.find(t=>t.id==='cafe');
export function atJobTask(position,task){return !!position&&!!task&&position.interiorHome==null&&(position.interiorBusiness??null)===(task.interiorBusiness??null)&&position.carId==null&&!position.rest&&!position.playground&&[position.x,position.z].every(Number.isFinite)&&Math.hypot(position.x-task.x,position.z-task.z)<=task.radius;}
export function currentJobTask(job,work){if(work?.taskRun&&workTaskDefinitions[work.name])return workTaskDefinitions[work.name].tasks[work.taskRun.step]||null;if(job?.stage==='pickup')return parcelStation;if(job?.stage==='deliver')return deliveryStop(job.destination);return null;}
