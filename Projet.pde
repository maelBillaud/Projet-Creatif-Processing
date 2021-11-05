import ddf.minim.*;
import ddf.minim.analysis.*;
import peasy.*;
import controlP5.*;
import processing.opengl.*;

// Song Manager Static Variables
static final String SONG_FILE_NAME = "souls.mp3";
static final short AUDIO_BUFFER = 1024;

// SuperShapes Variables
static final int TRIANGLES_AMOUNT = 200;
static final int FPS_TO_GENERATE_POINTS = 10;
static final float N1_1 = 0.2; // r1
static final float N1_2 = 1.7; // r1
static final float N1_3 = 1.7; // r1
static final float N2_1 = 0.2; // r2
static final float N2_2 = 1.7; // r2
static final float N2_3 = 1.7; // r2
static final float M_MIN= 7.0; // Minimum value of M to get the wanted supershape

PVector[][] GLOBE;
float PREVIOUS_M;
int RED, GREEN, BLUE, RAINBOW_HUE, RAINBOW_STYLE_NUMBER; // Value of the Red, Green and Blue slider, Hue when rainbowmode is activated, Number or rainbow style (btn)

// Gui Variables
ControlP5 CP5;
PeasyCam CAM;
boolean IS_REACTING_TO_BEATS;
boolean IS_RGB_TOGGLED; // Color mode of the shape

// Song variables
Minim MINIM;
AudioPlayer TRACK;
FFT FFT;
BeatDetect BEAT;
float LAST_AMPLITUDE;

// ---------------------------------------------------------- ControlP5 Funcs ----------------------------------------------

void InitGui()
{
  IS_RGB_TOGGLED = false;
  IS_REACTING_TO_BEATS = true;
  RAINBOW_STYLE_NUMBER = 0;
  RAINBOW_HUE = 61;
  RED = 215;
  GREEN = 61;
  BLUE = 184;
  CP5 = new ControlP5(this);
  CreateButton();
  CP5.setAutoDraw(false);
}

void DrawGui()
{
  hint(DISABLE_DEPTH_TEST);
  CAM.beginHUD();
  CP5.draw();
  CAM.endHUD();
  hint(ENABLE_DEPTH_TEST);
}

void CreateButton()
{
  int widthButton = width/2;
  int heightButton = height/20;
  int widthSlider = width/4;
  int heightSlider = height/40;
  
  color colorButton = color(147, 147, 147);
  color white = color(255,255,255);
  color black = color(0,0,0);
  color red = color(255,0,0);
  color green = color(0,255,0);
  color blue = color(0,0,255);
  
  CP5.addButton("React_To_Beats")
     .setPosition(0,0) // set the position of a controller (Button or Slider for example).
     .setSize(widthButton,heightButton) // set the size of a controller (Button or Slider for example).
     .setColorBackground(colorButton); // set the color of a controller (Button or Slider for example).
     
 CP5.addButton("React_To_Amplitude")
     .setPosition(widthButton,0)
     .setSize(widthButton,heightButton)
     .setColorBackground(colorButton);
     
CP5.addButton("Rainbow_Mode")
     .setPosition(widthButton + widthButton/2, 2*heightButton)
     .setSize(widthButton/6,heightButton)
     .setColorBackground(black);
     
CP5.addButton("RGB_Mode")
     .setPosition(widthButton + widthButton/1.25, 2*heightButton)
     .setSize(widthButton/6,heightButton)
     .setColorBackground(black);
     
 CP5.addSlider("RED")
     .setPosition(10,heightButton + 10)
     .setRange(0,255) // set the value that the slider can take
     .setSize(widthSlider, heightSlider)
     .setColorValue(white) // set the color of the slider's value
     .setColorActive(red) // set ther color of the slider when the mouse it's over it
     .setColorForeground(red) // set the color of the slider
     .setColorBackground(black); // set the color of the slider's background 

 CP5.addSlider("GREEN")
     .setPosition(10,2*(heightButton) + 10)
     .setRange(0,255)
     .setSize(widthSlider, heightSlider)
     .setColorValue(white)
     .setColorActive(green)
     .setColorForeground(green)
     .setColorBackground(black);

 CP5.addSlider("BLUE")
     .setPosition(10,3*(heightButton) + 10)
     .setRange(0,255)
     .setSize(widthSlider, heightSlider)
     .setColorValue(white)
     .setColorActive(blue)
     .setColorForeground(blue)
     .setColorBackground(black);
}


void React_To_Beats()
{
  IS_REACTING_TO_BEATS = true;
}

void React_To_Amplitude()
{
  IS_REACTING_TO_BEATS = false;
}
 
void RGB_Mode()
{
  IS_RGB_TOGGLED = true;
}

void Rainbow_Mode()
{
  IS_RGB_TOGGLED = false;
  RAINBOW_STYLE_NUMBER++;
  
  if(RAINBOW_STYLE_NUMBER >= 3) RAINBOW_STYLE_NUMBER = 0;
  
  switch(RAINBOW_STYLE_NUMBER)
  {
     case 0 :
       RAINBOW_HUE = 61;
       break;   
     case 1 :
       RAINBOW_HUE = 121;
       break;  
     case 2 :
        RAINBOW_HUE = 255;
        break;
   }
}

/////////////////////////////////////////////////////////////// SOUND Funcs ////////////////////////////////////////////////////////////////
void InitSound()
{
   MINIM = new Minim(this);
   TRACK = MINIM.loadFile(SONG_FILE_NAME, AUDIO_BUFFER);
   TRACK.loop();
 
   // The buffer size is the amount of time you give the computer to process a piece of audio. 
   // Lower buffer size will reduce latency which is especially important if live input is critical. 
   // The sample rate describes how many audio samples the program can capture in a second. 
   FFT = new FFT( TRACK.bufferSize(), TRACK.sampleRate());
   BEAT = new BeatDetect();
    
   LAST_AMPLITUDE = 0;
}

float GetMFromBeats()
{
  BEAT.detect(TRACK.mix);
  if (BEAT.isOnset()) return M_MIN;
  
  return 0;
}

float GetMFromAmplitude()
{
    if(LAST_AMPLITUDE == 0)
    {
      LAST_AMPLITUDE = ComputeAmplitudeSum();
      return 1;
    }
        
    float amplitudeSum = ComputeAmplitudeSum();
    float coef = ((amplitudeSum / LAST_AMPLITUDE) * 100 ) - 100;
    LAST_AMPLITUDE = amplitudeSum; 
    
    // Increase the m value
    if(coef > 0)
    {  
      return (coef / M_MIN) * (1 + (coef / 100));
    }
    
    // Decrease the m value
    if(coef < 0)
    {
      return (M_MIN - (abs(coef) / 100)) *( 1 - (abs(coef) / 100));
    }
 
    return PREVIOUS_M;
}

float ComputeAmplitudeSum()
{
    // Perform a forward FFT on the samples in song's mix buffer which contain the mix of both the left and right channels of the file
    FFT.forward(TRACK.mix);
    float ampSum = 0.0;
     
    for(int i = 0; i < FFT.specSize(); i++)
    {
      ampSum += FFT.getBand(i);
    }
 
    return ampSum;
}

void CloseSound() 
{
  // Close the sound since we are finish with it
  TRACK.close();
  // Close minim before exiting the sketch
  MINIM.stop();
}

// ---------------------------------------------------------------- SuperShape Funcs -----------------------------------------------------------

void InitShape()
{
  GLOBE = new PVector[TRIANGLES_AMOUNT+1][TRIANGLES_AMOUNT+1];
  GenerateShapePoints();
}

// Return a radius value depending the parameters of the wanted supershape
float TransformToSupershape(float theta, float n1, float n2, float n3, float m) 
{
  float a = 1;
  float b = 1;
  
  float t1 = pow(abs((1/a) * cos((m*theta) / 4)), n2);
  float t2 = pow(abs((1/b) * sin((m*theta) / 4)), n3);
  float result = pow((t1+t2), -1 / n1);
  
  return result;
}

// Use to generate the points of the supershape
void GenerateShapePoints()
{
  
  float m = 0.0;
  if(IS_REACTING_TO_BEATS)
  {
    m = GetMFromBeats();
  }
  else
  {
    m = GetMFromAmplitude();
  }

 float radius = 300 * height / 800;
 for(int i = 0; i < TRIANGLES_AMOUNT+1; i++) 
 {
      
   // For each latitude and longitude we compute the sphere and supershape radius
   // lat = phi  long = theta
   float phi = map(i, 0, TRIANGLES_AMOUNT, -HALF_PI, HALF_PI);
   float r2 = TransformToSupershape(phi, N2_1, N2_2, N2_3, m);
   
   for(int j = 0; j < TRIANGLES_AMOUNT+1; j++) 
   { 
     float theta = map(j, 0, TRIANGLES_AMOUNT, -PI, PI);
     float r1 = TransformToSupershape(theta, N1_1, N1_2, N2_3, m);
     
     float x = radius * r1 * cos(theta) * r2 * cos(phi);
     float y = radius * r1 * sin(theta) * r2 * cos(phi);
     float z = radius * r2 * sin(phi);
     GLOBE[i][j] = new PVector(x,y,z);
   }
 }
 
 // Refresh the value of the previous M
 PREVIOUS_M = m;
 
}

// Use to draw the supershape
void DrawShape()
{

  for(int i = 0; i < TRIANGLES_AMOUNT; i++)
  {
    
    if(IS_RGB_TOGGLED)
    {
       lights();
       colorMode(RGB);
       fill(RED, GREEN, BLUE);
    }
    else
    {
      colorMode(HSB);
      float hu = map(i, 0, TRIANGLES_AMOUNT, 183, 240);
      fill(hu % RAINBOW_HUE, 255, 255);
    }
    
    beginShape(TRIANGLE_STRIP);
    
    for(int j = 0; j < TRIANGLES_AMOUNT+1; j++)
    {
      PVector v1 = GLOBE[i][j];
      vertex(v1.x, v1.y, v1.z);
      
      PVector v2 = GLOBE[i+1][j];
      vertex(v2.x, v2.y, v2.z);
   }
   
   endShape();   
 }
}

// ----------------------------------------------------------------  END SuperShape Funcs -----------------------------------------------------------

void setup() 
{
 size(800, 800, OPENGL); 
 CAM = new PeasyCam(this, height);
 
 // Keep this order to make sure all variables are initialized
 InitGui();
 InitSound();
 InitShape();

}

void draw()
{ 
 background(0);
 noStroke();

 if(frameCount % FPS_TO_GENERATE_POINTS == 0) GenerateShapePoints();
 
 DrawGui();
 DrawShape();
}

void stop()
{
 CloseSound();
 super.stop();  // Close the current sketch
}
