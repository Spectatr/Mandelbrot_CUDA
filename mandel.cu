#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#define		X_RESN	800       /* x resolution */
#define		Y_RESN	800       /* y resolution */

typedef struct complextype
	{
        float real, imag;
	} Compl;

__global__ void calc(int* pixels);

int main ()
{
	Window		win;                            /* initialization for a window */
	unsigned
	int             width, height,                  /* window size */
                        x, y,                           /* window position */
                        border_width,                   /*border width in pixels */
                        display_width, display_height,  /* size of screen */
                        screen;                         /* which screen */

	char            *window_name = "Mandelbrot Set", *display_name = NULL;
	GC              gc;
	unsigned
	long		valuemask = 0;
	XGCValues	values;
	Display		*display;
	XSizeHints	size_hints;
	Pixmap		bitmap;
	XPoint		points[800];
	FILE		*fp, *fopen ();
	char		str[100];
	
	XSetWindowAttributes attr[1];

       /* Mandlebrot variables */
        int i, j, k;
        
        
       
	/* connect to Xserver */

	if (  (display = XOpenDisplay (display_name)) == NULL ) {
	   fprintf (stderr, "drawon: cannot connect to X server %s\n",
				XDisplayName (display_name) );
	exit (-1);
	}
	
	/* get screen size */

	screen = DefaultScreen (display);
	display_width = DisplayWidth (display, screen);
	display_height = DisplayHeight (display, screen);

	/* set window size */

	width = X_RESN;
	height = Y_RESN;

	/* set window position */

	x = 0;
	y = 0;

        /* create opaque window */

	border_width = 4;
	win = XCreateSimpleWindow (display, RootWindow (display, screen),
				x, y, width, height, border_width, 
				BlackPixel (display, screen), WhitePixel (display, screen));

	size_hints.flags = USPosition|USSize;
	size_hints.x = x;
	size_hints.y = y;
	size_hints.width = width;
	size_hints.height = height;
	size_hints.min_width = 300;
	size_hints.min_height = 300;
	
	XSetNormalHints (display, win, &size_hints);
	XStoreName(display, win, window_name);

        /* create graphics context */

	gc = XCreateGC (display, win, valuemask, &values);

	XSetBackground (display, gc, WhitePixel (display, screen));
	XSetForeground (display, gc, BlackPixel (display, screen));
	XSetLineAttributes (display, gc, 1, LineSolid, CapRound, JoinRound);

	attr[0].backing_store = Always;
	attr[0].backing_planes = 1;
	attr[0].backing_pixel = BlackPixel(display, screen);

	XChangeWindowAttributes(display, win, CWBackingStore | CWBackingPlanes | CWBackingPixel, attr);

	XMapWindow (display, win);
	XSync(display, 0);

        /* Calculate and draw points */

dim3 blockDim(16,16);
dim3 gridDim(800/blockDim.x,800/blockDim.y);
int* pixels;
int pixels2[800*800];

cudaMalloc((void**)&pixels,800*800*sizeof(int));

//timer
double gpuTime;
unsigned int hTimer;

cudaEvent_t start, stop;
float time,time2=0;
int h;

cudaEventCreate(&start);
cudaEventCreate(&stop);
cudaEventRecord( start, 0 );
calc<<<gridDim, blockDim>>>(pixels);
cudaEventRecord( stop, 0 );
cudaEventSynchronize( stop );
cudaEventElapsedTime( &time, start, stop );
time2+=time;
cudaEventDestroy( start );
cudaEventDestroy( stop );

printf("TIME: %f\n",time2/1000);
//

cudaMemcpy(pixels2,pixels,800*800*sizeof(int),cudaMemcpyDeviceToHost);

for(i=0;i<800;i++){
for(j=0;j<800;j++){
	if(pixels2[i*800+j]==1){
		XDrawPoint (display, win, gc, j, i);
	}
}}

	XFlush (display);
	cudaFree(pixels);
	sleep (1);

	/* Program Finished */

}

__global__ void calc(int* pixels){
Compl	z, c;
int i,j,k;
float	lengthsq, temp;

i=blockIdx.x*blockDim.x+threadIdx.x;
j=blockIdx.y*blockDim.y+threadIdx.y;



          z.real = z.imag = 0.0;
          c.real = ((float) j - 400.0)/200.0;               /* scale factors for 800 x 800 window */
	  c.imag = ((float) i - 400.0)/200.0;
          k = 0;

          do  {                                             /* iterate for pixel color */

            temp = z.real*z.real - z.imag*z.imag + c.real;
            z.imag = 2.0*z.real*z.imag + c.imag;
            z.real = temp;
            lengthsq = z.real*z.real+z.imag*z.imag;
            k++;

          } while (lengthsq < 4.0 && k < 100);

        if (k == 100){
	pixels[i*800+j]=1;
        }
}