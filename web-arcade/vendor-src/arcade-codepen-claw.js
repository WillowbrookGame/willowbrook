// Adapted from Masahito's MIT-licensed CodePen YPzzpep. See assets/codepen-claw/LICENSE.txt.
export function createTimerQueue(){let time=0,next=0;const jobs=new Map();return {add(fn,ms,repeat=false){const id=++next;jobs.set(id,{fn,due:time+Math.max(1,ms),ms:Math.max(1,ms),repeat});return id;},clear(id){jobs.delete(id);},tick(dt){time+=Math.max(0,Math.min(.05,Number(dt)||0))*1000;for(const [id,j]of [...jobs])if(j.due<=time&&jobs.has(id)){if(j.repeat)j.due+=j.ms;else jobs.delete(id);j.fn();}},dispose(){jobs.clear();},get size(){return jobs.size;}};}
export function createCodepenClaw({doc=globalThis.document}={}){
 const view=doc.createElement('div'),root=view.attachShadow({mode:'open'}),timers=createTimerQueue(),cleanup=[];let disposed=false,paused=false,ready=false,api=null,observer=null,loadError=false;
 const document=doc;const listen=(el,name,fn)=>{el.addEventListener(name,fn);cleanup.push(()=>el.removeEventListener(name,fn));};
 const setTimeout=(fn,ms)=>timers.add(fn,ms),setInterval=(fn,ms)=>timers.add(fn,ms,true),clearInterval=id=>timers.clear(id);
 const link=doc.createElement('link');link.rel='stylesheet';link.href=new URL('./assets/codepen-claw/machine.css'+new URL(import.meta.url).search,import.meta.url).href;
 root.innerHTML="                     \n      <div class=\"wrapper\">\n        <div class=\"collection-box pix\"></div>\n        <div class=\"claw-machine\">\n          <div class=\"box pix\">\n            <div class=\"machine-top pix\">\n              <div class=\"arm-joint pix\">\n                <div class=\"arm pix\">\n                  <div class=\"claws pix\"></div>\n                </div>\n              </div>\n              <div class=\"rail vert pix\"></div>\n              <div class=\"rail hori pix\"></div>\n            </div>\n            <div class=\"machine-bottom pix\">\n              <div class=\"collection-point pix\"></div>\n            </div>\n          </div>\n          <div class=\"control pix\">\n            <div class=\"cover left\"></div>\n            <button class=\"hori-btn pix\"></button>\n            <button class=\"vert-btn pix\"></button>\n            <div class=\"cover right\">\n              <div class=\"instruction pix\"></div>\n            </div>\n            <div class=\"cover bottom\"></div>\n            <div class=\"cover top\">\n              <div class=\"collection-arrow pix\"></div>\n            </div>\n            <div class=\"collection-point pix\"></div>\n          </div>\n        </div>\n      </div>\n      <div class=\"sign\">\n        by masahito / <span>Original CodePen by Masahito</span>\n      </div>\n    ";root.prepend(link);view.tabIndex=0;view.setAttribute('aria-label','Original claw machine. Hold Right, release, then hold Up and release. Collect toys from the chute.');view.style.cssText='position:relative;width:100%;height:100%;min-height:0';
 let cssReady=false;link.onload=()=>{cssReady=true;if(view.isConnected)initialize();};link.onerror=()=>{loadError=true;view.textContent='The claw machine artwork could not load. Please reopen the cabinet.';};
 function fit(){const r=view.getBoundingClientRect();view.style.setProperty('--fit',String(Math.max(.1,Math.min(r.width/400,r.height/600))));}
 function initialize(){if(ready||disposed||!cssReady)return;ready=true;view.style.setProperty('--fit','1');
                     const elements = {
        clawMachine: root.querySelector('.claw-machine'),
        box: root.querySelector('.box'),
        collectionBox: root.querySelector('.collection-box'),
        collectionArrow: root.querySelector('.collection-arrow'),
        toys: [],
      }

      const settings = {
        targetToy: null,
        collectedNumber: 0,
      }

      const m = 2
      const toys = {
        bear: {
          w: 20 * m,
          h: 27 * m,
        },
        bunny: {
          w: 20 * m,
          h: 29 * m,
        },
        golem: {
          w: 20 * m,
          h: 27 * m,
        },
        cucumber: {
          w: 16 * m,
          h: 28 * m,
        },
        penguin: {
          w: 24 * m,
          h: 22 * m,
        },
        robot: {
          w: 20 * m,
          h: 30 * m,
        },
      }

      const sortedToys = [...Object.keys(toys), ...Object.keys(toys)].sort(
        () => 0.5 - Math.random(),
      )

      const cornerBuffer = 16

      const machineBuffer = {
        x: 36,
        y: 16,
      }

      const radToDeg = rad => Math.round(rad * (180 / Math.PI))
      const calcX = (i, n) => i % n
      const calcY = (i, n) => Math.floor(i / n)

      const {
        width: machineWidth,
        height: machineHeight,
        top: machineTop,
      } = root.querySelector('.claw-machine').getBoundingClientRect()

      const { height: machineTopHeight } = root.querySelector('.machine-top')
        .getBoundingClientRect()

      const { height: machineBottomHeight, top: machineBottomTop } = root.querySelector('.machine-bottom')
        .getBoundingClientRect()

      const maxArmLength = machineBottomTop - machineTop - machineBuffer.y

      const adjustAngle = angle => {
        const adjustedAngle = angle % 360
        return adjustedAngle < 0 ? adjustedAngle + 360 : adjustedAngle
      }

      const randomN = (min, max) => {
        return Math.round(min - 0.5 + Math.random() * (max - min + 1))
      }

      //* classes *//

      class Button {
 constructor({className,isLocked,pressAction,releaseAction}) {this.el=root.querySelector('.'+className);this.isLocked=isLocked;this.held=false;this.press=()=>{if(disposed||paused||this.isLocked||this.held)return;this.held=true;pressAction?.();};this.release=()=>{if(!this.held)return;this.held=false;if(!this.isLocked)releaseAction?.();};this.cancel=()=>{this.held=false;};
 this.el.type='button';this.el.setAttribute('aria-label',className==='hori-btn'?'Hold right, then release':'Hold up, then release');
 listen(this.el,'pointerdown',e=>{e.preventDefault();e.stopPropagation();this.el.setPointerCapture?.(e.pointerId);this.press();});for(const name of ['pointerup','pointercancel','lostpointercapture'])listen(this.el,name,e=>{e.preventDefault();e.stopPropagation();this.release();});if(!isLocked)this.activate();}
 activate(){this.isLocked=false;this.el.classList.add('active');} deactivate(){this.isLocked=true;this.held=false;this.el.classList.remove('active');}
 }
 class WorldObject {
        constructor(props) {
          Object.assign(this, {
            x: 0,
            y: 0,
            z: 0,
            angle: 0,
            transformOrigin: { x: 0, y: 0 },
            interval: null,
            default: {},
            moveWith: [],
            el: props.className && root.querySelector(`.${props.className}`),
            ...props,
          })
          this.setStyles()
          if (props.className) {
            const { width, height } = this.el.getBoundingClientRect()
            this.w = width
            this.h = height
          }
          ;['x', 'y', 'w', 'h'].forEach(key => {
            this.default[key] = this[key]
          })
        }
        setStyles() {
          Object.assign(this.el.style, {
            left: `${this.x}px`,
            top: !this.bottom && `${this.y}px`,
            bottom: this.bottom,
            width: `${this.w}px`,
            height: `${this.h}px`,
            transformOrigin: this.transformOrigin,
          })
          this.el.style.zIndex = this.z
        }
        setClawPos(clawPos) {
          this.clawPos = clawPos
        }
        setTransformOrigin(transformOrigin) {
          this.transformOrigin =
            transformOrigin === 'center'
              ? 'center'
              : `${transformOrigin.x}px ${transformOrigin.y}px`
          this.setStyles()
        }
        handleNext(next) {
          clearInterval(this.interval)
          if (next) next()
        }
        resumeMove({ moveKey, target, moveTime, next }) {
          this.interval = null
          this.move({ moveKey, target, moveTime, next })
        }
        resizeShadow() {
          elements.box.style.setProperty('--scale', 0.5 + this.h / maxArmLength / 2)
        }
        move({ moveKey, target, moveTime, next }) {
          if (this.interval) {
            this.handleNext(next)
          } else {
            const moveTarget = target ?? this.default[moveKey]
            this.interval = setInterval(() => {
              const distance =
                Math.abs(this[moveKey] - moveTarget) < 10
                  ? Math.abs(this[moveKey] - moveTarget)
                  : 10
              const increment = this[moveKey] > moveTarget ? -distance : distance
              if (
                increment > 0
                  ? this[moveKey] < moveTarget
                  : this[moveKey] > moveTarget
              ) {
                this[moveKey] += increment
                this.setStyles()
                if (moveKey === 'h') this.resizeShadow()
                if (this.moveWith.length) {
                  this.moveWith.forEach(obj => {
                    if (!obj) return
                    obj[moveKey === 'h' ? 'y' : moveKey] += increment
                    obj.setStyles()
                  })
                }
              } else {
                this.handleNext(next)
              }
            }, moveTime || 100)
          }
        }
        distanceBetween(target) {
          return Math.round(
            Math.sqrt(
              Math.pow(this.x - target.x, 2) + Math.pow(this.y - target.y, 2),
            ),
          )
        }
      }
      class Toy extends WorldObject {
        constructor(props) {
          const toyType = sortedToys[props.index]
          const size = toys[toyType]
          super({
            el: Object.assign(document.createElement('div'), {
              className: `toy pix ${toyType}`,
            }),
            x:
              cornerBuffer +
              calcX(props.index, 4) * ((machineWidth - cornerBuffer * 3) / 4) +
              size.w / 2 +
              randomN(-6, 6),
            y:
              machineBottomTop -
              machineTop +
              cornerBuffer +
              calcY(props.index, 4) *
                ((machineBottomHeight - cornerBuffer * 2) / 3) -
              size.h / 2 +
              randomN(-2, 2),
            z: 0,
            toyType,
            ...size,
            ...props,
          })
          elements.box.append(this.el)
          const toy = this

          listen(this.el,'click', () => this.collectToy(toy))
          elements.toys.push(this)
        }
        collectToy(toy) {
 if(disposed||paused||toy.collected||!toy.el.classList.contains('selected'))return;toy.collected=true;
          toy.el.classList.remove('selected')
          toy.x = machineWidth / 2 - toy.w / 2
          toy.y = machineHeight / 2 - toy.h / 2
          toy.z = 7
          toy.el.style.setProperty('--rotate-angle', '0deg')
          toy.setTransformOrigin('center')
          toy.el.classList.add('display')
          elements.clawMachine.classList.add('show-overlay')
          settings.collectedNumber++
          elements.collectionBox.appendChild(
            Object.assign(document.createElement('div'), {
              className: `toy-wrapper ${
                settings.collectedNumber > 6 ? 'squeeze-in' : ''
              }`,
              innerHTML: `<div class="toy pix ${toy.toyType}"></div>`,
            }),
          )
          setTimeout(() => {
            elements.clawMachine.classList.remove('show-overlay')
            if (!root.querySelector('.selected'))
              elements.collectionArrow.classList.remove('active')
          }, 1000)
        }
        setRotateAngle() {
          const angle =
            radToDeg(
              Math.atan2(
                this.y + this.h / 2 - this.clawPos.y,
                this.x + this.w / 2 - this.clawPos.x,
              ),
            ) - 90
          const adjustedAngle = Math.round(adjustAngle(angle))
          this.angle =
            adjustedAngle < 180 ? adjustedAngle * -1 : 360 - adjustedAngle
          this.el.style.setProperty('--rotate-angle', `${this.angle}deg`)
        }
      }

      //* set up *//
      elements.box.style.setProperty('--shadow-pos', `${maxArmLength}px`)

      const armJoint = new WorldObject({
        className: 'arm-joint',
      })

      const vertRail = new WorldObject({
        className: 'vert',
        moveWith: [null, armJoint],
      })

      const arm = new WorldObject({
        className: 'arm',
      })

      armJoint.resizeShadow()

      armJoint.move({
        moveKey: 'y',
        target: machineTopHeight - machineBuffer.y,
        moveTime: 50,
        next: () =>
          vertRail.resumeMove({
            moveKey: 'x',
            target: machineBuffer.x,
            moveTime: 50,
            next: () => {
              Object.assign(armJoint.default, {
                y: machineTopHeight - machineBuffer.y,
                x: machineBuffer.x,
              })
              Object.assign(vertRail.default, {
                x: machineBuffer.x,
              })
              activateHoriBtn()
            },
          }),
      })

      const doOverlap = (a, b) => {
        return b.x > a.x && b.x < a.x + a.w && b.y > a.y && b.y < a.y + a.h
      }

      const getClosestToy = () => {
        const claw = {
          y: armJoint.y + maxArmLength + machineBuffer.y + 7,
          x: armJoint.x + 7,
          w: 40,
          h: 32,
        }
        const overlappedToys = elements.toys.filter(t => {
          return !t.collected && !t.el.classList.contains('selected') && !t.el.classList.contains('grabbed') && doOverlap(t, claw)
        })

        if (overlappedToys.length) {
          const toy = overlappedToys.sort((a, b) => b.index - a.index)[0]
          toy.setTransformOrigin({
            x: claw.x - toy.x,
            y: claw.y - toy.y,
          })
          toy.setClawPos({
            x: claw.x,
            y: claw.y,
          })
          settings.targetToy = toy
        }
      }

      new Array(12).fill('').forEach((_, i) => {
        if (i === 8) return
        new Toy({ index: i })
      })

      const stopHoriBtnAndActivateVertBtn = () => {
        armJoint.interval = null
        horiBtn.deactivate()
        vertBtn.activate()
      }

      const activateHoriBtn = () => {
        horiBtn.activate()
        ;[vertRail, armJoint, arm].forEach(c => (c.interval = null))
      }

      const dropToy = () => {
        arm.el.classList.add('open')
        if (settings.targetToy) {
          settings.targetToy.z = 3
          settings.targetToy.move({
            moveKey: 'y',
            target: machineHeight - settings.targetToy.h - 30,
            moveTime: 50,
          })
          ;[vertRail, armJoint, arm].forEach(obj => (obj.moveWith[0] = null))
        }
        setTimeout(() => {
          arm.el.classList.remove('open')
          activateHoriBtn()
          if (settings.targetToy) {
            settings.targetToy.el.classList.add('selected')
            elements.collectionArrow.classList.add('active')
            settings.targetToy = null
          }
        }, 700)
      }

      const grabToy = () => {
        if (settings.targetToy) {
          ;[vertRail, armJoint, arm].forEach(
            obj => (obj.moveWith[0] = settings.targetToy),
          )
          settings.targetToy.setRotateAngle()
          settings.targetToy.el.classList.add('grabbed')
        } else {
          arm.el.classList.add('missed')
        }
      }

      const horiBtn = new Button({
        className: 'hori-btn',
        isLocked: true,
        pressAction: () => {
          arm.el.classList.remove('missed')
          vertRail.move({
            moveKey: 'x',
            target: machineWidth - armJoint.w - machineBuffer.x,
            next: stopHoriBtnAndActivateVertBtn,
          })
        },
        releaseAction: () => {
          clearInterval(vertRail.interval)
          stopHoriBtnAndActivateVertBtn()
        },
      })

      const vertBtn = new Button({
        className: 'vert-btn',
        isLocked: true,
        pressAction: () => {
          if (vertBtn.isLocked) return
          armJoint.move({
            moveKey: 'y',
            target: machineBuffer.y,
          })
        },
        releaseAction: () => {
          clearInterval(armJoint.interval)
          vertBtn.deactivate()
          getClosestToy()
          setTimeout(() => {
            arm.el.classList.add('open')
            arm.move({
              moveKey: 'h',
              target: maxArmLength,
              next: () =>
                setTimeout(() => {
                  arm.el.classList.remove('open')
                  grabToy()
                  arm.resumeMove({
                    moveKey: 'h',
                    next: () => {
                      vertRail.resumeMove({
                        moveKey: 'x',
                        next: () => {
                          armJoint.resumeMove({
                            moveKey: 'y',
                            next: dropToy,
                          })
                        },
                      })
                    },
                  })
                }, 500),
            })
          }, 500)
        },
      })
 api={input(a,p){if(a==='right'||a==='up'){const b=a==='right'?horiBtn:vertBtn;p?b.press():b.release();}else if(a==='action'&&p){const selected=elements.toys.find(t=>t.el.classList.contains('selected'));if(selected)selected.collectToy(selected);}},pause(v){paused=v;view.toggleAttribute('data-paused',v);if(v){if(horiBtn.held){clearInterval(vertRail.interval);vertRail.interval=null;}if(vertBtn.held){clearInterval(armJoint.interval);armJoint.interval=null;}horiBtn.cancel();vertBtn.cancel();} },status(){return {message:settings.collectedNumber+' / 11 toys collected. '+(root.querySelector('.selected')?'Tap the toy in the chute, or press Collect.':!horiBtn.isLocked?'Hold Right, then release to choose your position.':!vertBtn.isLocked?'Hold Up, then release to drop the claw.':'Watch the claw!')};}};
 fit();if(globalThis.ResizeObserver){observer=new ResizeObserver(fit);observer.observe(view);} }
 return {view,mount(){if(cssReady)initialize();},input(a,p){if(!paused)api?.input(a,p);},tick(dt){if(!paused&&!disposed)timers.tick(dt);},pause(v){paused=v;api?.pause(v);view.toggleAttribute('data-paused',v);},status(){return api?.status()||{message:loadError?'Artwork could not load. Close and reopen this cabinet.':'Loading the original claw machine...'};},dispose(){disposed=true;timers.dispose();observer?.disconnect();cleanup.forEach(fn=>fn());link.onload=link.onerror=null;view.remove();}};
}
