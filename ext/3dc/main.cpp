#include <G3D/G3DAll.h>
#include <GLG3D/GLG3D.h>
#include "app.h"

G3D_START_AT_MAIN();

int main(int argc, char **argv)
{
	GApp::Settings settings;

	settings.window.width = 400;
	settings.window.height = 400;
	settings.window.stereo = true;

	return App(settings).run();
}
