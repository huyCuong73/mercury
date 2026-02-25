package ante

import (
	"testing"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/mercuryd/tests/integration"
	"github.com/huyCuong73/mercury/tests/integration/ante"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestAnte_Integration(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.AnteIntegrationApp](integration.CreateEvmd, "evm.AnteIntegrationApp")
	ante.TestIntegrationAnteHandler(t, create)
}

func BenchmarkAnteHandler(b *testing.B) {
	create := testapp.ToEvmAppCreator[evm.AnteIntegrationApp](integration.CreateEvmd, "evm.AnteIntegrationApp")
	// Run the benchmark with a mock EVM app
	ante.RunBenchmarkAnteHandler(b, create)
}

func TestValidateHandlerOptions(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.AnteIntegrationApp](integration.CreateEvmd, "evm.AnteIntegrationApp")
	ante.RunValidateHandlerOptionsTest(t, create)
}
