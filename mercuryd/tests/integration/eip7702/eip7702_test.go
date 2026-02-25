package eip7702

import (
	"testing"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/mercuryd/tests/integration"
	"github.com/huyCuong73/mercury/tests/integration/eip7702"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestEIP7702IntegrationTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.IntegrationNetworkApp](integration.CreateEvmd, "evm.IntegrationNetworkApp")
	eip7702.TestEIP7702IntegrationTestSuite(t, create)
}
