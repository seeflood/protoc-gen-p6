import (
    rawGRPC "google.golang.org/grpc"
    grpc_api "mosn.io/layotto/pkg/grpc"
)
{{$pb_name := .PackageName}}
{{$component_name := .ComponentPackageName }}

func NewAPI(ac *grpc_api.ApplicationContext) grpc_api.GrpcAPI {
	return &server{
		appId: ac.AppId,
		components: ac.{{.Name}},
	}
}

type server struct {
	appId       string
	components  map[string]{{ .ComponentPackageName }}.{{.Name}}
}

{{range .MethodSet}}
func (s *server) {{.Name}}(ctx context.Context, in *{{$pb_name}}.{{.Request}}) (*{{$pb_name}}.{{.Reply}}, error){
	// find the component
	comp := s.components[in.ComponentName]
	if comp == nil {
		return nil, invalidArgumentError("{{.Name}}", grpc_api.ErrComponentNotFound, "{{$pb_name}}", in.ComponentName)
	}

	// convert request
	var req {{$component_name}}.{{.Request}}
	bytes, err := json.Marshal(in)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "Error when json.Marshal the request: %s", err.Error())
	}
	err = json.Unmarshal(bytes, &req)
    if err != nil {
		return nil, status.Errorf(codes.Internal, "Error when json.Unmarshal the request: %s", err.Error())
    }

	// delegate to the component
	resp, err := comp.{{.Name}}(ctx, &req)
	if err != nil {
		return nil, status.Errorf(codes.Internal, err.Error())
	}

	// convert response
	var out {{$pb_name}}.{{.Reply}}
	bytes, err = json.Marshal(resp)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "Error when json.Marshal the response: %s", err.Error())
	}
	err = json.Unmarshal(bytes, &out)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "Error when json.Unmarshal the response: %s", err.Error())
	}
	return &out, nil
}
{{end}}

func invalidArgumentError(method string, format string, a ...interface{}) error {
	err := status.Errorf(codes.InvalidArgument, format, a...)
	log.DefaultLogger.Errorf(fmt.Sprintf("%s fail: %+v", method, err))
	return err
}

func (s *server) Init(conn *rawGRPC.ClientConn) error {
	return nil
}

func (s *server) Register(rawGrpcServer *rawGRPC.Server) error {
	{{ .PackageName }}.Register{{.Name}}Server(rawGrpcServer, s)
	return nil
}
