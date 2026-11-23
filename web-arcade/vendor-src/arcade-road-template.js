// Adapted from Hunor Marton's MIT-licensed JwWLJo. See assets/arcade-road-template/LICENSE.txt.
import * as THREE from './vendor/three.module.js';
export const roadRenderRadius=24;
export function reconcileRoadRows(active,currentRow,lastRow,create,remove){
 const first=Math.max(-9,currentRow-roadRenderRadius),last=Math.min(lastRow,currentRow+roadRenderRadius);
 for(const [index,value] of active)if(index<first||index>last){remove(value,index);active.delete(index);}
 for(let index=first;index<=last;index++)if(!active.has(index))active.set(index,create(index));
 return active.size;
}
export function roadVehiclePosition(initial,direction,speed,elapsed){const lo=-420,hi=420,span=hi-lo;return lo+(((initial+(direction?1:-1)*speed*elapsed-lo)%span)+span)%span;}
export function mountRoadTemplate(container,{onScore,onGameOver}={}){
if(!document.getElementById('road-template-styles')){const link=document.createElement('link');link.id='road-template-styles';link.rel='stylesheet';link.href=new URL('./arcade-road-template.css',import.meta.url).href;document.head.append(link);}
const root=document.createElement('div');root.className='road-template';root.tabIndex=0;container.append(root);
root.innerHTML='<canvas class="game" aria-label="Road crossing game"></canvas><div id="controls"><div><button id="forward" aria-label="Forward">&#9650;</button><button id="left" aria-label="Left">&#9664;</button><button id="backward" aria-label="Backward">&#9660;</button><button id="right" aria-label="Right">&#9654;</button></div></div><div id="score">0</div><div id="result-container"><div id="result"><h2>Game Over</h2><p>Your score: <span id="final-score"></span></p><button id="retry">Retry</button></div></div><small class="credit">Game by Hunor Marton - MIT</small>';
const abort=new AbortController();const byId=id=>root.querySelector('#'+id);let paused=false,disposed=false,gameOver=false,simulationTime=0,frameDelta=0,lastFrame=performance.now();
function release(object,textures){const geometries=new Set(),materials=new Set(),maps=new Set();object.traverse(n=>{if(n.geometry)geometries.add(n.geometry);for(const m of (Array.isArray(n.material)?n.material:[n.material]).filter(Boolean)){materials.add(m);if(textures)for(const value of Object.values(m))if(value?.isTexture)maps.add(value);}});geometries.forEach(g=>g.dispose());materials.forEach(m=>m.dispose());maps.forEach(t=>t.dispose());}

const minTileIndex = -8;
const maxTileIndex = 8;
const tilesPerRow = maxTileIndex - minTileIndex + 1;
const tileSize = 42;

function Camera() {
  const size = 300;
  const viewRatio = Math.max(1,root.clientWidth) / Math.max(1,root.clientHeight);
  const width = viewRatio < 1 ? size : size * viewRatio;
  const height = viewRatio < 1 ? size / viewRatio : size;

  const camera = new THREE.OrthographicCamera(
    width / -2, // left
    width / 2, // right
    height / 2, // top
    height / -2, // bottom
    100, // near
    900 // far
  );

  camera.up.set(0, 0, 1);
  camera.position.set(300, -300, 300);
  camera.lookAt(0, 0, 0);

  return camera;
}

function Texture(width, height, rects) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d");
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, width, height);
  context.fillStyle = "rgba(0,0,0,0.6)";
  rects.forEach((rect) => {
    context.fillRect(rect.x, rect.y, rect.w, rect.h);
  });
  return new THREE.CanvasTexture(canvas);
}

const carFrontTexture = new Texture(40, 80, [{ x: 0, y: 10, w: 30, h: 60 }]);
const carBackTexture = new Texture(40, 80, [{ x: 10, y: 10, w: 30, h: 60 }]);
const carRightSideTexture = new Texture(110, 40, [
  { x: 10, y: 0, w: 50, h: 30 },
  { x: 70, y: 0, w: 30, h: 30 },
]);
const carLeftSideTexture = new Texture(110, 40, [
  { x: 10, y: 10, w: 50, h: 30 },
  { x: 70, y: 10, w: 30, h: 30 },
]);

const truckFrontTexture = Texture(30, 30, [
  { x: 5, y: 0, w: 10, h: 30 },
]);
const truckRightSideTexture = Texture(25, 30, [
  { x: 15, y: 5, w: 10, h: 10 },
]);
const truckLeftSideTexture = Texture(25, 30, [
  { x: 15, y: 15, w: 10, h: 10 },
]);


function Car(initialTileIndex, direction, color) {
  const car = new THREE.Group();
  car.position.x = initialTileIndex * tileSize;
  if (!direction) car.rotation.z = Math.PI;

  const main = new THREE.Mesh(
    new THREE.BoxGeometry(60, 30, 15),
    new THREE.MeshLambertMaterial({ color, flatShading: true })
  );
  main.position.z = 12;
  main.castShadow = true;
  main.receiveShadow = true;
  car.add(main);

  const cabin = new THREE.Mesh(new THREE.BoxGeometry(33, 24, 12), [
    new THREE.MeshPhongMaterial({
      color: 0xcccccc,
      flatShading: true,
      map: carBackTexture,
    }),
    new THREE.MeshPhongMaterial({
      color: 0xcccccc,
      flatShading: true,
      map: carFrontTexture,
    }),
    new THREE.MeshPhongMaterial({
      color: 0xcccccc,
      flatShading: true,
      map: carRightSideTexture,
    }),
    new THREE.MeshPhongMaterial({
      color: 0xcccccc,
      flatShading: true,
      map: carLeftSideTexture,
    }),
    new THREE.MeshPhongMaterial({ color: 0xcccccc, flatShading: true }), // top
    new THREE.MeshPhongMaterial({ color: 0xcccccc, flatShading: true }), // bottom
  ]);
  cabin.position.x = -6;
  cabin.position.z = 25.5;
  cabin.castShadow = true;
  cabin.receiveShadow = true;
  car.add(cabin);

  const frontWheel = Wheel(18);
  car.add(frontWheel);

  const backWheel = Wheel(-18);
  car.add(backWheel);

  return car;
}

function DirectionalLight() {
  const dirLight = new THREE.DirectionalLight();
  dirLight.position.set(-100, -100, 200);
  dirLight.up.set(0, 0, 1);
  dirLight.castShadow = true;

  dirLight.shadow.mapSize.width = 2048;
  dirLight.shadow.mapSize.height = 2048;

  dirLight.shadow.camera.up.set(0, 0, 1);
  dirLight.shadow.camera.left = -400;
  dirLight.shadow.camera.right = 400;
  dirLight.shadow.camera.top = 400;
  dirLight.shadow.camera.bottom = -400;
  dirLight.shadow.camera.near = 50;
  dirLight.shadow.camera.far = 400;

  return dirLight;
}

function Grass(rowIndex) {
  const grass = new THREE.Group();
  grass.position.y = rowIndex * tileSize;
  const createSection = (color) =>
    new THREE.Mesh(
      new THREE.BoxGeometry(tilesPerRow * tileSize, tileSize, 3),
      new THREE.MeshLambertMaterial({ color })
    );

  const middle = createSection(0xbaf455);
  middle.receiveShadow = true;
  grass.add(middle);

  const left = createSection(0x99c846);
  left.position.x = -tilesPerRow * tileSize;
  grass.add(left);

  const right = createSection(0x99c846);
  right.position.x = tilesPerRow * tileSize;
  grass.add(right);

  return grass;
}

const metadata = [];

const map = new THREE.Group();

const renderedRows=new Map();
function initializeMap(){
 for(const child of [...map.children]){release(child,false);map.remove(child);}
 renderedRows.clear();metadata.length=0;addRows();
}
function addRows(){metadata.push(...generateRows(20).map(row=>({...row,born:simulationTime})));syncRows();}
function createRow(rowIndex){
 if(rowIndex<=0){const grass=Grass(rowIndex);map.add(grass);return grass;}
 const rowData=metadata[rowIndex-1];
 const row=rowData.type==='forest'?Grass(rowIndex):Road(rowIndex);
 if(rowData.type==='forest')rowData.trees.forEach(({tileIndex,height})=>row.add(Tree(tileIndex,height)));
 else rowData.vehicles.forEach(vehicle=>{
  const model=rowData.type==='car'?Car(vehicle.initialTileIndex,rowData.direction,vehicle.color):Truck(vehicle.initialTileIndex,rowData.direction,vehicle.color);
  model.position.x=roadVehiclePosition(vehicle.initialTileIndex*tileSize,rowData.direction,rowData.speed,simulationTime-rowData.born);
  vehicle.ref=model;row.add(model);
 });
 map.add(row);return row;
}
function syncRows(){reconcileRoadRows(renderedRows,position.currentRow,metadata.length,createRow,(row,index)=>{release(row,false);map.remove(row);for(const vehicle of metadata[index-1]?.vehicles||[])delete vehicle.ref;});}

const player = Player();

function Player() {
  const player = new THREE.Group();

  const body = new THREE.Mesh(
    new THREE.BoxGeometry(15, 15, 20),
    new THREE.MeshLambertMaterial({
      color: "white",
      flatShading: true,
    })
  );
  body.position.z = 10;
  body.castShadow = true;
  body.receiveShadow = true;
  player.add(body);

  const cap = new THREE.Mesh(
    new THREE.BoxGeometry(2, 4, 2),
    new THREE.MeshLambertMaterial({
      color: 0xf0619a,
      flatShading: true,
    })
  );
  cap.position.z = 21;
  cap.castShadow = true;
  cap.receiveShadow = true;
  player.add(cap);

  const playerContainer = new THREE.Group();
  playerContainer.add(player);

  return playerContainer;
}

const position = {
  currentRow: 0,
  currentTile: 0,
};

const movesQueue = [];

function initializePlayer() {
  // Initialize the Three.js player object
  player.position.x = 0;
  player.position.y = 0;
  player.children[0].position.z = 0;

  // Initialize metadata
  position.currentRow = 0;
  position.currentTile = 0;

  // Clear the moves queue
  movesQueue.length = 0;
}

function queueMove(direction) {
 if(paused||disposed||gameOver||movesQueue.length>=3)return;
  const isValidMove = endsUpInValidPosition(
    {
      rowIndex: position.currentRow,
      tileIndex: position.currentTile,
    },
    [...movesQueue, direction]
  );

  if (!isValidMove) return;

  movesQueue.push(direction);
}
function stepCompleted() {
  const direction = movesQueue.shift();

  if (direction === "forward") position.currentRow += 1;
  if (direction === "backward") position.currentRow -= 1;
  if (direction === "left") position.currentTile -= 1;
  if (direction === "right") position.currentTile += 1;

  // Add new rows if the player is running out of them
  if (position.currentRow > metadata.length - 10) addRows();
  syncRows();
  const scoreDOM = byId("score");
  if (scoreDOM) scoreDOM.innerText = position.currentRow.toString();
 onScore?.(position.currentRow);
}

function Renderer() {
  const canvas = root.querySelector("canvas.game");
  if (!canvas) throw new Error("Canvas not found");

  const renderer = new THREE.WebGLRenderer({
    alpha: true,
    antialias: true,
    canvas: canvas,
  });
  renderer.setPixelRatio(Math.min(2,window.devicePixelRatio||1));
  renderer.setSize(Math.max(1,root.clientWidth), Math.max(1,root.clientHeight));
  renderer.shadowMap.enabled = true;

  return renderer;
}

function Road(rowIndex) {
  const road = new THREE.Group();
  road.position.y = rowIndex * tileSize;

  const createSection = (color) =>
    new THREE.Mesh(
      new THREE.PlaneGeometry(tilesPerRow * tileSize, tileSize),
      new THREE.MeshLambertMaterial({ color })
    );

  const middle = createSection(0x454a59);
  middle.receiveShadow = true;
  road.add(middle);

  const left = createSection(0x393d49);
  left.position.x = -tilesPerRow * tileSize;
  road.add(left);

  const right = createSection(0x393d49);
  right.position.x = tilesPerRow * tileSize;
  road.add(right);

  return road;
}

function Tree(tileIndex, height) {
  const tree = new THREE.Group();
  tree.position.x = tileIndex * tileSize;

  const trunk = new THREE.Mesh(
    new THREE.BoxGeometry(15, 15, 20),
    new THREE.MeshLambertMaterial({
      color: 0x4d2926,
      flatShading: true,
    })
  );
  trunk.position.z = 10;
  tree.add(trunk);

  const crown = new THREE.Mesh(
    new THREE.BoxGeometry(30, 30, height),
    new THREE.MeshLambertMaterial({
      color: 0x7aa21d,
      flatShading: true,
    })
  );
  crown.position.z = height / 2 + 20;
  crown.castShadow = true;
  crown.receiveShadow = true;
  tree.add(crown);

  return tree;
}

function Truck(initialTileIndex, direction, color) {
  const truck = new THREE.Group();
  truck.position.x = initialTileIndex * tileSize;
  if (!direction) truck.rotation.z = Math.PI;

  const cargo = new THREE.Mesh(
    new THREE.BoxGeometry(70, 35, 35),
    new THREE.MeshLambertMaterial({
      color: 0xb4c6fc,
      flatShading: true,
    })
  );
  cargo.position.x = -15;
  cargo.position.z = 25;
  cargo.castShadow = true;
  cargo.receiveShadow = true;
  truck.add(cargo);

  const cabin = new THREE.Mesh(new THREE.BoxGeometry(30, 30, 30), [
    new THREE.MeshLambertMaterial({
      color,
      flatShading: true,
      map: truckFrontTexture,
    }), // front
    new THREE.MeshLambertMaterial({
      color,
      flatShading: true,
    }), // back
    new THREE.MeshLambertMaterial({
      color,
      flatShading: true,
      map: truckLeftSideTexture,
    }),
    new THREE.MeshLambertMaterial({
      color,
      flatShading: true,
      map: truckRightSideTexture,
    }),
    new THREE.MeshPhongMaterial({ color, flatShading: true }), // top
    new THREE.MeshPhongMaterial({ color, flatShading: true }), // bottom
  ]);
  cabin.position.x = 35;
  cabin.position.z = 20;
  cabin.castShadow = true;
  cabin.receiveShadow = true;

  truck.add(cabin);

  const frontWheel = Wheel(37);
  truck.add(frontWheel);

  const middleWheel = Wheel(5);
  truck.add(middleWheel);

  const backWheel = Wheel(-35);
  truck.add(backWheel);

  return truck;
}

function Wheel(x) {
  const wheel = new THREE.Mesh(
    new THREE.BoxGeometry(12, 33, 12),
    new THREE.MeshLambertMaterial({
      color: 0x333333,
      flatShading: true,
    })
  );
  wheel.position.x = x;
  wheel.position.z = 6;
  return wheel;
}

function calculateFinalPosition(currentPosition, moves) {
  return moves.reduce((position, direction) => {
    if (direction === "forward")
      return {
        rowIndex: position.rowIndex + 1,
        tileIndex: position.tileIndex,
      };
    if (direction === "backward")
      return {
        rowIndex: position.rowIndex - 1,
        tileIndex: position.tileIndex,
      };
    if (direction === "left")
      return {
        rowIndex: position.rowIndex,
        tileIndex: position.tileIndex - 1,
      };
    if (direction === "right")
      return {
        rowIndex: position.rowIndex,
        tileIndex: position.tileIndex + 1,
      };
    return position;
  }, currentPosition);
}

function endsUpInValidPosition(currentPosition, moves) {
  // Calculate where the player would end up after the move
  const finalPosition = calculateFinalPosition(currentPosition, moves);

  // Detect if we hit the edge of the board
  if (
    finalPosition.rowIndex === -1 ||
    finalPosition.tileIndex === minTileIndex - 1 ||
    finalPosition.tileIndex === maxTileIndex + 1
  ) {
    // Invalid move, ignore move command
    return false;
  }

  // Detect if we hit a tree
  const finalRow = metadata[finalPosition.rowIndex - 1];
  if (
    finalRow &&
    finalRow.type === "forest" &&
    finalRow.trees.some((tree) => tree.tileIndex === finalPosition.tileIndex)
  ) {
    // Invalid move, ignore move command
    return false;
  }

  return true;
}

function generateRows(amount) {
  const rows = [];
  for (let i = 0; i < amount; i++) {
    const rowData = generateRow();
    rows.push(rowData);
  }
  return rows;
}

function generateRow() {
  const type = randomElement(["car", "truck", "forest"]);
  if (type === "car") return generateCarLaneMetadata();
  if (type === "truck") return generateTruckLaneMetadata();
  return generateForesMetadata();
}

function randomElement(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function generateForesMetadata() {
  const occupiedTiles = new Set();
  const trees = Array.from({ length: 4 }, () => {
    let tileIndex;
    do {
      tileIndex = THREE.MathUtils.randInt(minTileIndex, maxTileIndex);
    } while (occupiedTiles.has(tileIndex));
    occupiedTiles.add(tileIndex);

    const height = randomElement([20, 45, 60]);

    return { tileIndex, height };
  });

  return { type: "forest", trees };
}

function generateCarLaneMetadata() {
  const direction = randomElement([true, false]);
  const speed = randomElement([125, 156, 188]);

  const occupiedTiles = new Set();

  const vehicles = Array.from({ length: 3 }, () => {
    let initialTileIndex;
    do {
      initialTileIndex = THREE.MathUtils.randInt(minTileIndex, maxTileIndex);
    } while (occupiedTiles.has(initialTileIndex));
    occupiedTiles.add(initialTileIndex - 1);
    occupiedTiles.add(initialTileIndex);
    occupiedTiles.add(initialTileIndex + 1);
    const color = randomElement([0xa52523, 0xbdb638, 0x78b14b]);

    return { initialTileIndex, color };
  });

  return { type: "car", direction, speed, vehicles };
}

function generateTruckLaneMetadata() {
  const direction = randomElement([true, false]);
  const speed = randomElement([125, 156, 188]);

  const occupiedTiles = new Set();

  const vehicles = Array.from({ length: 2 }, () => {
    let initialTileIndex;
    do {
      initialTileIndex = THREE.MathUtils.randInt(minTileIndex, maxTileIndex);
    } while (occupiedTiles.has(initialTileIndex));
    occupiedTiles.add(initialTileIndex - 2);
    occupiedTiles.add(initialTileIndex - 1);
    occupiedTiles.add(initialTileIndex);
    occupiedTiles.add(initialTileIndex + 1);
    occupiedTiles.add(initialTileIndex + 2);

    const color = randomElement([0xa52523, 0xbdb638, 0x78b14b]);

    return { initialTileIndex, color };
  });

  return { type: "truck", direction, speed, vehicles };
}

const moveClock={running:false,at:0,start(){this.running=true;this.at=simulationTime;},stop(){this.running=false;},getElapsedTime(){return simulationTime-this.at;}};

function animatePlayer() {
  if (!movesQueue.length) return;

  if (!moveClock.running) moveClock.start();

  const stepTime = 0.2; // Seconds it takes to take a step
  const progress = Math.min(1, moveClock.getElapsedTime() / stepTime);

  setPosition(progress);
  setRotation(progress);

  // Once a step has ended
  if (progress >= 1) {
    stepCompleted();
    moveClock.stop();
  }
}

function setPosition(progress) {
  const startX = position.currentTile * tileSize;
  const startY = position.currentRow * tileSize;
  let endX = startX;
  let endY = startY;

  if (movesQueue[0] === "left") endX -= tileSize;
  if (movesQueue[0] === "right") endX += tileSize;
  if (movesQueue[0] === "forward") endY += tileSize;
  if (movesQueue[0] === "backward") endY -= tileSize;

  player.position.x = THREE.MathUtils.lerp(startX, endX, progress);
  player.position.y = THREE.MathUtils.lerp(startY, endY, progress);
  player.children[0].position.z = Math.sin(progress * Math.PI) * 8;
}

function setRotation(progress) {
  let endRotation = 0;
  if (movesQueue[0] == "forward") endRotation = 0;
  if (movesQueue[0] == "left") endRotation = Math.PI / 2;
  if (movesQueue[0] == "right") endRotation = -Math.PI / 2;
  if (movesQueue[0] == "backward") endRotation = Math.PI;

  player.children[0].rotation.z = THREE.MathUtils.lerp(
    player.children[0].rotation.z,
    endRotation,
    progress
  );
}

const clock={getDelta(){return frameDelta;}};

function animateVehicles(){
 for(const index of renderedRows.keys()){
  const row=metadata[index-1];if(!row?.vehicles)continue;
  for(const vehicle of row.vehicles)if(vehicle.ref)vehicle.ref.position.x=roadVehiclePosition(vehicle.initialTileIndex*tileSize,row.direction,row.speed,simulationTime-row.born);
 }
}

byId("forward")
  ?.addEventListener("click", () => queueMove("forward"),{signal:abort.signal});

byId("backward")
  ?.addEventListener("click", () => queueMove("backward"),{signal:abort.signal});

byId("left")
  ?.addEventListener("click", () => queueMove("left"),{signal:abort.signal});

byId("right")
  ?.addEventListener("click", () => queueMove("right"),{signal:abort.signal});



function hitTest() {
  const row = metadata[position.currentRow - 1];
  if (!row) return;
  if (row.type === "car" || row.type === "truck") {
    const playerBoundingBox = new THREE.Box3();
    playerBoundingBox.setFromObject(player);

    row.vehicles.forEach(({ ref }) => {
      if (!ref) throw Error("Vehicle reference is missing");

      const vehicleBoundingBox = new THREE.Box3();
      vehicleBoundingBox.setFromObject(ref);

      if (playerBoundingBox.intersectsBox(vehicleBoundingBox)) {
        if (!resultDOM || !finalScoreDOM) return;
        resultDOM.style.visibility = "visible";
        finalScoreDOM.innerText = position.currentRow.toString();
 if(!gameOver){gameOver=true;onGameOver?.(position.currentRow);}
      }
    });
  }
}

const scene = new THREE.Scene();
scene.add(player);
scene.add(map);

const ambientLight = new THREE.AmbientLight();
scene.add(ambientLight);

const dirLight = DirectionalLight();
dirLight.target = player;
player.add(dirLight);

const camera = Camera();
player.add(camera);
const scoreDOM = byId("score");
const resultDOM = byId("result-container");
const finalScoreDOM = byId("final-score");

initializeGame();

root.querySelector("#retry")?.addEventListener("click", initializeGame,{signal:abort.signal});

function initializeGame() {
 gameOver=false;simulationTime=0;moveClock.stop();onScore?.(0);
  initializePlayer();
  initializeMap();

  // Initialize UI
  if (scoreDOM) scoreDOM.innerText = "0";
  if (resultDOM) resultDOM.style.visibility = "hidden";
}

const renderer = Renderer();


function animate(now) {
 if(paused||disposed)return;
 frameDelta=Math.min(.05,Math.max(0,(now-lastFrame)/1000));lastFrame=now;simulationTime+=frameDelta;
 if(!gameOver){animateVehicles();animatePlayer();hitTest();}

  renderer.render(scene, camera);
}
const keys={ArrowUp:'forward',w:'forward',ArrowDown:'backward',s:'backward',ArrowLeft:'left',a:'left',ArrowRight:'right',d:'right'};
root.addEventListener('keydown',event=>{const direction=keys[event.key];if(direction){event.preventDefault();event.stopPropagation();queueMove(direction);}},{signal:abort.signal});
root.addEventListener('pointerdown',()=>root.focus({preventScroll:true}),{signal:abort.signal});
function resize(){const w=Math.max(1,root.clientWidth),h=Math.max(1,root.clientHeight),ratio=w/h,size=300,width=ratio<1?size:size*ratio,height=ratio<1?size/ratio:size;camera.left=-width/2;camera.right=width/2;camera.top=height/2;camera.bottom=-height/2;camera.updateProjectionMatrix();renderer.setSize(w,h);}
const observer=new ResizeObserver(resize);observer.observe(root);resize();root.focus({preventScroll:true});renderer.setAnimationLoop(animate);
let visibilityPaused=false;const visibility=()=>{if(document.hidden){visibilityPaused=!paused;pause();}else if(visibilityPaused){visibilityPaused=false;resume();}};document.addEventListener('visibilitychange',visibility,{signal:abort.signal});
function pause(){if(disposed)return;paused=true;renderer.setAnimationLoop(null);}
function resume(){if(disposed)return;paused=false;lastFrame=performance.now();renderer.setAnimationLoop(animate);root.focus({preventScroll:true});}
function dispose(){if(disposed)return;pause();disposed=true;abort.abort();observer.disconnect();release(scene,true);for(const t of [carFrontTexture,carBackTexture,carRightSideTexture,carLeftSideTexture,truckFrontTexture,truckRightSideTexture,truckLeftSideTexture])t.dispose();dirLight.shadow.map?.dispose();renderer.renderLists.dispose();renderer.dispose();renderer.forceContextLoss();renderedRows.clear();metadata.length=0;root.remove();}
return {root,pause,resume,dispose,restart(){if(disposed)return;initializeGame();resume();},getState(){return {score:position.currentRow,paused,gameOver,disposed,renderedRows:renderedRows.size,generatedRows:metadata.length};}};
}




// Arcade-shell adapter. Mount only after view is attached and sized.
export function createRoadTemplate(options={}){
 const view=document.createElement('div');view.className='road-template-view';view.style.cssText='position:relative;width:100%;height:100%;min-height:0';
 let controller=null,closed=false,isPaused=false;
 return {view,mount(){if(!closed&&!controller){controller=mountRoadTemplate(view,options);if(isPaused)controller.pause();}},input(action,pressed){if(!pressed||closed||isPaused||!controller)return;const direction={up:'forward',down:'backward',left:'left',right:'right',forward:'forward',backward:'backward'}[action];if(direction)controller.root.querySelector('#'+direction)?.click();if(action==='restart')controller.restart();},tick(){},pause(value){if(closed||isPaused===!!value)return;isPaused=!!value;if(controller)(isPaused?controller.pause():controller.resume());},get status(){if(!controller)return {message:'Ready'};const state=controller.getState();return {message:state.gameOver?'Game over - '+state.score+' rows':state.paused?'Paused':'Rows crossed: '+state.score};},dispose(){if(closed)return;closed=true;controller?.dispose();controller=null;view.remove();}};
}

