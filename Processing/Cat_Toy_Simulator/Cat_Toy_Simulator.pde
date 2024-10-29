/*
  Cat Toy Simulator
  Author: David Lee
  Last Modified Date: Oct 22
*/

import processing.serial.*;

Serial myPort;   // Create object from Serial class
String val;      // Data received from the serial port

int canvasSize = 1500;
int analogMax = 4095;

int joystickSpeed = 9;
float impulseDecay = 6; // per second
float impulseStart = 30;
float currImpulse = 0;
float handXPos;
float handYPos;
float handR = 25;
boolean lastPressed = false;

int minCats = 7;         // number of cats to start with
int maxCats = 12;                  
int currCats;
PImage[] catImages;
int uniqueCats = 6;      // number of unique images, img file names are cat1, cat2, etc.
Cat[] cats;              // set in setup(), currently active cats

//int newCatDuration = 5;         // time it takes for a new cat to spawn, in seconds
float walkSpeedMin = 50;
float walkSpeedMax = 200;
float pounceSpeedMin = 100;     // pounce starting velocity
float pounceSpeedMax = 850;     // pounce starting velocity
float pounceProbability = 0.5;  // probability of next task being pounce
float pounceOffsetMax = 0.3;    // max angle inaccuracy, makes cats' pounces not as accurate
float taskDurationMin = 1;
float taskDurationMax = 5;
float catRBuffer = 0.8;

float gravity = 500;
float boundsBuffer = 10;      // make sure cats don't go out of bounds
float xMinBound, xMaxBound;   // set in setup(), calculated bounds based on buffer and sketch size
float yMinBound, yMaxBound;   // yMinBound is based on the radius of the image instead 
float lastFrame = 0;
float dt = 1/60;

enum TaskType {
    walkLeft, 
    walkRight, 
    pause, 
    pounce
}

class Task {
  TaskType type;
  float duration;
  float timer = 0;
  float vx = 0, vy = 0; // velocity of pounce if applicable
}

class Cat {
  float xPos, yPos;
  PImage img;
  float r;  // collider radius
  Task task;
  float walkSpeed;
  Boolean attached = false;
  
  Cat(float xpos_in, float ypos_in, PImage img_in, float r_in, float w_in){
      xPos = xpos_in;
      yPos = ypos_in;
      img = img_in;
      r = r_in;
      walkSpeed = w_in;
  }
}

class CatManager{
  // Assigns a new task to the cat
  // If new cat, the task options will not include pounce
  void AssignTask(Cat cat, boolean newCat){
    // Set task type, duration, timer = 0
    Task t = new Task();
    TaskType type;
    float pounceThresh;
    if (newCat){
      pounceThresh = 0;
    } else {
      pounceThresh = pounceProbability;
    }
    float interval = (1-pounceThresh)/3; 
    float rand = random(0,1);
    println("random: " + rand);
    if (rand < pounceThresh){
      // Pounce
      // If pounce, set new velocity vector directions
      type = TaskType.pounce;
      // Stretch goal: For now, the cats will always jump at the mouse directly. Implementing a random offset would be nice.
      float dx = handXPos - cat.xPos;
      float dy = handYPos - cat.yPos;
      float mag = pow(dx*dx+dy*dy, 0.5);
      float nx = dx/mag;
      float ny = dy/mag;
      float s = random(pounceSpeedMin, pounceSpeedMax);
      float vx = s * nx;
      float vy = s * ny;
      t.vx = vx;
      t.vy = vy;
    } else if (rand < pounceThresh + interval){
      // Walk left
      type = TaskType.walkLeft;
    } else if (rand < pounceThresh + 2*interval){
      // Walk right
      type = TaskType.walkRight;
    } else {
      // Pause
      type = TaskType.pause;
    }
    t.type = type;
    float dur;
    if (type == TaskType.pounce){
      dur = 20;
    } else {
      dur = random(taskDurationMin, taskDurationMax);
    }
    t.duration = dur;
    t.timer = 0;
    cat.task = t;
  }
  
  // Changes the direction the cat is walking in. 
  void ChangeDirection(Cat cat){
    if (cat.task.type == TaskType.walkLeft){
      cat.task.type = TaskType.walkRight;
    } else if (cat.task.type == TaskType.walkRight){
      cat.task.type = TaskType.walkLeft;
    }
  }
  
  // Handles the movement of the cat based on the tasks
  // Also makes sure that the cat stays in bounds
  void HandleCat(Cat cat){
    if (cat.task.timer > cat.task.duration){
      AssignTask(cat, false);
    }
    switch(cat.task.type){
      case walkRight:
        cat.xPos += cat.walkSpeed * dt;
        if (cat.xPos > xMaxBound){
          cat.xPos = xMaxBound;
          ChangeDirection(cat);
        }
        break;
      case walkLeft:
        cat.xPos -= cat.walkSpeed * dt;
        if (cat.xPos < xMinBound){
          cat.xPos = xMinBound;
          ChangeDirection(cat);
        }
        break;
      case pause:
        // Do nothing
        break;
      case pounce:
        float dx = cat.task.vx * dt;
        float dy = cat.task.vy * dt;
        cat.xPos += dx;
        cat.yPos += dy;
        cat.task.vy += (gravity * dt);
        // If the cat's x-dimensions are out of bounds, move the cat back to the closest x bound and set the x velocity
        // to zero
        if (cat.xPos < xMinBound || cat.xPos > xMaxBound){
          cat.task.vx = 0;
          if (cat.xPos < xMinBound){
            cat.xPos = xMinBound;
          } else {
            cat.xPos = xMaxBound;
          }
        }
        // If the cat's y position exceeds the bounds, move it back inside the bounds and set the y velocity to zero
        if (cat.yPos < yMinBound){
          println("case cat.yPos < yMinBound");
          cat.task.vy = 0;
          cat.yPos = yMinBound;
        }
        // If the cat's y position is less than or equal to (yMaxBound - cat.r), the cat has returned to the ground,
        // reassign a new task to the cat
        if (cat.yPos > yMaxBound - cat.r){
          cat.yPos = yMaxBound - cat.r;
          AssignTask(cat, false);
        }
        break;
      default:
        println("Strange option in switch.");
        break;
    }
    cat.task.timer += dt;
  }
  
  Boolean CheckCollision(Cat cat){
    // If the distance between the center of the hand and the cat is less than the sum of their radii, collision detected
    float dx = cat.xPos - handXPos;
    float dy = cat.yPos - handYPos;
    float mag = pow(dx*dx + dy*dy, 0.5);
    return mag <= (cat.r*catRBuffer + handR);
  }
  
}

CatManager manager;

void setup()
{
  size(1000, 700);
  printArray(Serial.list());
  String portName = Serial.list()[6];
  println(portName);
  myPort = new Serial(this, portName, 9600); // ensure baudrate is consistent with arduino sketch
  
  // Bounds setup
  xMinBound = boundsBuffer;
  xMaxBound = width - boundsBuffer;
  yMinBound = boundsBuffer;
  yMaxBound = height - boundsBuffer;
  
  // HAND SETUP
  // Make hand start at the center of the screen
  handXPos = width/2;
  handYPos = height/2;
  
  // CATS SETUP
  manager = new CatManager();
  currCats = minCats;
  // Load cat images into catImages
  catImages = new PImage[minCats];
  for (int i = 0; i < minCats; ++i){
    String imgName = "cat" + str(i%uniqueCats + 1) + ".png";
    PImage img = loadImage(imgName);
    img.resize(120,120);
    catImages[i] = img;
  }
  // Populate cats array
  // TODO: Not sure yet if I can sense how many cats there currently are by checking if null
  // If this is possible, delete the currCats var
  cats = new Cat[maxCats]; 
  for (int i = 0; i < minCats; ++i){
    float xPos = random(xMinBound, xMaxBound);
    PImage img = catImages[i];
    float r = max(img.width, img.height)/2;
    float yPos = yMaxBound - r;
    float w = random(walkSpeedMin, walkSpeedMax);
    Cat c = new Cat(xPos, yPos, img, r, w);
    manager.AssignTask(c, true);
    cats[i] = c;
  }
  
  println("Setup end");
  
}

void draw() // ~60 fps
{
  dt = (millis() - lastFrame)/1000;
  lastFrame = millis();

  if ( myPort.available() > 0) {            // If data is available,
    val = myPort.readStringUntil('\n');     // read it and store it in val
  }
  
  val = trim(val);
  if ( val != null ) {
    background(255);
    //println(val);
    String[] partitions = split(val, '|');
    if (partitions.length < 2){
      println("Missing one or both inputs");
      exit();
    } else {
      // Draw hand
      int[] xyz = int(split(partitions[0], ','));
      int buttonVal = int(partitions[1]);
      boolean buttonPressed = (buttonVal == 0);
      float xDiff = 0;
      float yDiff = 0;
      // Joystick contribution (move in the direction of joystick)
      if (xyz.length == 3) {
        int x = xyz[0];
        int y = xyz[1];
        int z = xyz[2];
        int joystickCenter = 1900;
        int buffer = 14;
        if (!(joystickCenter-buffer < x && x < joystickCenter+buffer) || 
            !(joystickCenter-buffer < y && y < joystickCenter+buffer)) {
          xDiff += map(x, 0, analogMax, -joystickSpeed/2, joystickSpeed/2);
          yDiff += map(y, 0, analogMax, -joystickSpeed/2, joystickSpeed/2);
        }
      }
      
      // Decay impulse
      currImpulse = max(currImpulse - impulseDecay, 0);
      // Reset impulse on trigger
      if (!buttonPressed){
        lastPressed = false;
      } else if (!lastPressed){
        currImpulse = impulseStart;
        lastPressed = true;
      }
       
      // Button contribution (add additional impulse in the direction of xDiff & yDiff)
      if (currImpulse > 0){
        // Get unit vector for current direction
        PVector v = new PVector(xDiff, yDiff);
        v.normalize();
        v.mult(currImpulse);
        xDiff += v.x;
        yDiff += v.y;
      }
      handXPos += xDiff;
      handYPos += yDiff;
      
      Boolean stuck = false;
      // CAT LOGIC
      for (int i = 0; i < currCats; ++i){
        manager.HandleCat(cats[i]);
        if (manager.CheckCollision(cats[i]) && !stuck && !buttonPressed){
          handXPos = cats[i].xPos;
          handYPos = cats[i].yPos;
          stuck = true; // Can only get stuck to one cat at a time
        }
        PImage img = cats[i].img;
        // Adjustments for cat.xPos and cat.yPos pointing to center of the image
        image(img, cats[i].xPos - (img.width/2), cats[i].yPos - (img.height/2));
        //circle(cats[i].xPos - (img.width/2), cats[i].yPos - (img.height/2), 5); 
        //circle(cats[i].xPos, cats[i].yPos, 5); 
        //if (cats[i].task.type == TaskType.pounce){
          //fill(255,0,0);
          //circle(cats[i].xPos + cats[i].task.vx, cats[i].yPos + cats[i].task.vy, 10); 
          //fill(255,255,255);
        //}
      }
      circle(handXPos, handYPos, 25); 
    }
  }
}
