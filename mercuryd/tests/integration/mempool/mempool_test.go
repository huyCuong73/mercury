package mempool

import (
	"testing"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/mercuryd/tests/integration"
	testapp "github.com/huyCuong73/mercury/testutil/app"
	"github.com/stretchr/testify/suite"

	"github.com/huyCuong73/mercury/tests/integration/mempool"
)

func TestMempoolIntegrationTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.IntegrationNetworkApp](integration.CreateEvmd, "evm.IntegrationNetworkApp")
	suite.Run(t, mempool.NewMempoolIntegrationTestSuite(create))
}
