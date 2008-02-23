#include "app.h"

App::App(const GApp::Settings &settings) : GApp(settings)
{
	// custom app init
}

void App::onInit()
{
	// do most init here
	
	sky = Sky::fromFile(dataDir + "sky/");

	skyParameters = SkyParameters(G3D::toSeconds(11, 00, 00, AM));
	lighting = Lighting::fromSky(sky, skyParameters, Color3::white());

	lighting->lightArray.append(lighting->shadowedLightArray);
	lighting->shadowedLightArray.clear();

	// debugPane->addCheckBox("Use explicit checking", &explicitCheck);

	toneMap->setEnabled(false);
}

void App::onLogic()
{
	// sim logic and ai code
}

void App::onNetwork()
{
	// poll net messages
}

void App::onSimulation(RealTime rdt, SimTime sdt, SimTime idt)
{
	// time advancement
}

bool App::onEvent(const GEvent &e)
{
	// return true to stop bubbling
	return false;
}

void App::onUserInput(UserInput *ui)
{
	// do key handling
}

void App::onPose(Array<PosedModelRef>& posed3D, Array<PosedModel2DRef>& posed2D)
{
	// append models that onGraphics should render
}

void App::onGraphics(RenderDevice *rd, Array<PosedModelRef> &posed3D,
		Array<PosedModel2DRef>& posed2D)
{
	Array<PosedModel::Ref> opaque, transparent;
	LightingRef localLighting = toneMap->prepareLighting(lighting);
	SkyParameters localSky = toneMap->prepareSkyParameters(skyParameters);

	toneMap->beginFrame(rd);
	rd->setProjectionAndCameraMatrix(defaultCamera);

	rd->setColorClearValue(Color3(0.1f, 0.5f, 1.0f));
	rd->clear(false, true, true);
	sky->render(rd, localSky);

	rd->enableDepthWrite();
	rd->setTexture(0,NULL);
	rd->disableLighting();
	rd->setColor(Color3::blue());
	rd->setLineWidth(2.0);
	
	Draw::axes(CoordinateFrame(Vector3(0, 4, 0)), rd);
	Draw::sphere(Sphere(Vector3::zero(), 0.5f), rd, Color3::white());
	Draw::box(AABox(Vector3(-3,-0.5,-0.5), Vector3(-2,0.5,0.5)),
		rd, Color3::green());

	if (posed3D.size() > 0)
	{
		Vector3 lookVector = renderDevice->getCameraToWorldMatrix().lookVector();
		PosedModel::sort(posed3D, lookVector, opaque, transparent);

		for (int i = 0; i < opaque.size(); ++i) {
			opaque[i]->render(renderDevice);
		}

		for (int i = 0; i < transparent.size(); ++i) {
			transparent[i]->render(renderDevice);
		}
	}

	rd->disableLighting();
	sky->renderLensFlare(rd, localSky);

	toneMap->endFrame(rd);

	PosedModel2D::sortAndRender(rd, posed2D);
}

void App::onConsoleCommand(const std::string &str)
{
	TextInput t(TextInput::FROM_STRING, str);

	if (t.hasMore() && (t.peek().type() == Token::SYMBOL))
	{
		std::string cmd = toLower(t.readSymbol());
		if (cmd == "exit")
		{
			setExitCode(0);
			return;
		}
		else if (cmd == "help")
		{
			printConsoleHelp();
			return;
		}
	}

	console->printf("Unkown command\n");
	printConsoleHelp();
}

void App::printConsoleHelp()
{
	console->printf("exit          - Quit the program\n");
	console->printf("help          - Display this text\n\n");
	console->printf("~/ESC         - Open/Close console\n");
	console->printf("F2            - Enable first-person camera control\n");
}

void App::onCleanup()
{
	// clean stuff up here
}
