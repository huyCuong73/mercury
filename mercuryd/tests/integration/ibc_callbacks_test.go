package integration

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/tests/integration/x/ibc/callbacks"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestIBCCallback(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.IBCCallbackIntegrationApp](CreateEvmd, "evm.IBCCallbackIntegrationApp")
	suite.Run(t, callbacks.NewKeeperTestSuite(create))
}
