#ifndef _APP_H_
#define _APP_H_

#include <G3D/G3DAll.h>
#include <GLG3D/GLG3D.h>

class App : public GApp
{
public:
	LightingRef		lighting;
	SkyParameters	skyParameters;
	SkyRef				sky;

	App(const GApp::Settings& settings = GApp::Settings());

	virtual void onInit();
	virtual void onLogic();
	virtual void onNetwork();
	virtual void onSimulation(RealTime rdt, SimTime sdt, SimTime idt);
	virtual void onPose(Array<PosedModelRef>& posed3D, Array<PosedModel2DRef>& posed2D);
	virtual void onGraphics(RenderDevice *rd, Array<PosedModelRef>& posed3D, Array<PosedModel2DRef>& posed2D);
	virtual bool onEvent(const GEvent &e);
	virtual void onUserInput(UserInput *ui);
	virtual void onConsoleCommand(const std::string &cmd);
	void printConsoleHelp();
	virtual void onCleanup();
};

#endif
